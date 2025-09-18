{
  pkgs,
  config,
  username,
  fullName,
  email,
  flakeDir,
  ...
}: let
  sshPassphraseFile = config.sops.secrets."ssh-key-passphrase".path;
  upgradeResultFile = "/var/lib/upgrade-service/last-result";
  batteryThreshold = 30;

  killBraveScript = ''
    # Kill Brave using flatpak
    ${pkgs.flatpak}/bin/flatpak kill com.brave.Browser 2>/dev/null || true

    # Poll to check if Brave is actually dead
    for i in {1..20}; do
      if ! ${pkgs.flatpak}/bin/flatpak ps --columns=application 2>/dev/null | ${pkgs.ripgrep}/bin/rg -q "com.brave.Browser"; then
        break
      fi
      sleep 0.1
    done
  '';

  upgradeAndPowerOffWorker = pkgs.writeShellScript "system-upgrade-worker" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    FINAL_ACTION=$1
    RESULT_FILE="${upgradeResultFile}"
    UPGRADE_SUCCESS=0

    # These variables need to be available for the maintenance check later
    GIT_STATUS=""
    EXPECTED_STATUS=" M flake.lock"

    log_header()  { echo -e "\n\e[1;35m--- $1 ---\e[0m"; }
    log_info()    { echo -e "\e[34m[INFO]\e[0m $1"; }
    log_success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
    log_error()   { echo -e "\e[1;31m[ERROR]\e[0m $1"; }

    # Function to write result for notification service
    write_result() {
      mkdir -p $(dirname "$RESULT_FILE")
      echo "$1" > "$RESULT_FILE"
    }

    # Function to perform final action
    perform_final_action() {
      # Wait for Syncthing before shutdown/reboot (even on error)
      wait_for_syncthing

      # Turn off screen
      turn_off_screen

      log_header "Proceeding with final action: $FINAL_ACTION"

      if [ "$FINAL_ACTION" = "reboot" ]; then
        ${pkgs.systemd}/bin/systemctl reboot
      elif [ "$FINAL_ACTION" = "shutdown" ]; then
        ${pkgs.systemd}/bin/systemctl poweroff
      fi
    }

    # Cleanup function that always runs
    cleanup_and_exit() {
      local exit_code=$1
      if [ $exit_code -ne 0 ]; then
        log_error "Upgrade failed with error code $exit_code"
      fi
      perform_final_action
      exit $exit_code
    }

    # Battery check function
    check_battery() {
      log_info "Checking battery status..."

      # Check if we're on AC power
      AC_ONLINE=0
      if [ -f /sys/class/power_supply/AC/online ]; then
        AC_ONLINE=$(cat /sys/class/power_supply/AC/online 2>/dev/null || echo 0)
      elif [ -f /sys/class/power_supply/ADP1/online ]; then
        AC_ONLINE=$(cat /sys/class/power_supply/ADP1/online 2>/dev/null || echo 0)
      fi

      # Find battery
      BATTERY_PATH=""
      for bat in /sys/class/power_supply/BAT*; do
        if [ -d "$bat" ]; then
          BATTERY_PATH="$bat"
          break
        fi
      done

      # If no battery found, we're on desktop - proceed
      if [ -z "$BATTERY_PATH" ]; then
        log_info "No battery detected (desktop system) - proceeding"
        return 0
      fi

      # Check battery capacity
      if [ -f "$BATTERY_PATH/capacity" ]; then
        BATTERY_LEVEL=$(cat "$BATTERY_PATH/capacity")
        log_info "Battery level: $BATTERY_LEVEL%"

        if [ "$AC_ONLINE" -eq 1 ]; then
          log_info "AC power connected - proceeding"
          return 0
        elif [ "$BATTERY_LEVEL" -ge ${toString batteryThreshold} ]; then
          log_info "Battery level sufficient (>=${toString batteryThreshold}%) - proceeding"
          return 0
        else
          log_error "Battery too low ($BATTERY_LEVEL% < ${toString batteryThreshold}%) and not charging"
          write_result "error:battery_low:$BATTERY_LEVEL"
          return 1
        fi
      fi
    }

    # Wait for Syncthing to finish syncing
    wait_for_syncthing() {
      log_info "Checking Syncthing sync status..."

      # Check if syncthing is running
      if ! ${pkgs.systemd}/bin/systemctl is-active --quiet syncthing@${username}.service; then
        log_info "Syncthing not running - skipping sync check"
        return 0
      fi

      MAX_WAIT=300  # 5 minutes max wait
      WAITED=0

      while [ $WAITED -lt $MAX_WAIT ]; do
        # Query Syncthing API for sync status
        SYNC_STATUS=$(${pkgs.curl}/bin/curl -s http://localhost:8384/rest/db/completion \
          -H "X-API-Key: $(cat /home/${username}/.config/syncthing/config.xml | \
          ${pkgs.gnused}/bin/sed -n 's/.*<apikey>\(.*\)<\/apikey>.*/\1/p')" 2>/dev/null || echo "")

        if [ -z "$SYNC_STATUS" ]; then
          log_info "Unable to query Syncthing status - proceeding anyway"
          break
        fi

        COMPLETION=$(echo "$SYNC_STATUS" | ${pkgs.jq}/bin/jq -r '.completion' 2>/dev/null || echo "0")

        if [ "$(echo "$COMPLETION >= 100" | ${pkgs.bc}/bin/bc)" -eq 1 ]; then
          log_success "Syncthing sync complete"
          break
        fi

        log_info "Syncthing sync at $COMPLETION% - waiting..."
        sleep 10
        WAITED=$((WAITED + 10))
      done

      if [ $WAITED -ge $MAX_WAIT ]; then
        log_info "Syncthing sync timeout - proceeding anyway"
      fi
    }

    # Turn off screen
    turn_off_screen() {
      log_info "Turning off display..."

      # For console/TTY
      ${pkgs.kbd}/bin/setterm -blank force -powersave on > /dev/tty1 2>/dev/null || true

      # Disable console blanking wakeup on activity temporarily
      echo 0 > /sys/module/kernel/parameters/consoleblank 2>/dev/null || true
    }

    # Main upgrade logic starts here
    clear
    log_header "System Upgrade Service Started"

    # Perform battery check first
    if ! check_battery; then
      cleanup_and_exit 1
    fi

    # Kill Brave and wait for it to close
    log_info "Killing Brave browser..."
    ${killBraveScript}

    # Exit sway session
    SU_AS_USER="${pkgs.su}/bin/su -l ${username} -c"

    log_info "Closing graphical session..."
    $SU_AS_USER "swaymsg exit" || true

    # Give a moment for the session to fully terminate
    sleep 2

    # Start flatpak operations early in parallel
    log_info "Starting Flatpak updates in background..."
    (
      runuser -l ${username} -c "flatpak update -y" 2>&1 | tee /tmp/flatpak-update.log || true
      runuser -l ${username} -c "flatpak uninstall --unused -y" 2>&1 | tee -a /tmp/flatpak-update.log || true
    ) &
    FLATPAK_PID=$!

    cd "${flakeDir}" || {
      log_error "Failed to change directory to ${flakeDir}"
      write_result "error:cd_failed"
      cleanup_and_exit 1
    }

    # Alias for git commands, reusing the su command defined earlier
    GIT_AS_USER="$SU_AS_USER"

    log_info "Verifying repository is in a clean state..."
    if ! $GIT_AS_USER "${pkgs.git}/bin/git -C ${flakeDir} diff --quiet HEAD --"; then
      log_error "Git repository is dirty. Aborting upgrade."
      write_result "error:dirty_repo"
      wait $FLATPAK_PID || true  # Still wait for flatpak to finish
      cleanup_and_exit 1
    fi
    log_success "Repository is clean."

    log_info "Updating flake inputs..."
    $GIT_AS_USER "${pkgs.nix}/bin/nix flake update --flake ${flakeDir}"

    GIT_STATUS=$($GIT_AS_USER "${pkgs.git}/bin/git -C ${flakeDir} status --porcelain")

    if [ -z "$GIT_STATUS" ]; then
      log_info "No changes detected after update. System is already up-to-date."
      write_result "success:no_updates"
      UPGRADE_SUCCESS=1
    elif [ "$GIT_STATUS" = "$EXPECTED_STATUS" ]; then
      log_success "Verified: Only flake.lock was modified. Proceeding."

      $GIT_AS_USER "${pkgs.git}/bin/git -C ${flakeDir} add flake.lock"
      PASSPHRASE=$(cat ${sshPassphraseFile})

      log_info "Committing flake.lock..."
      # Create the commit with proper environment
      $GIT_AS_USER "
        export GIT_AUTHOR_NAME='${fullName}'
        export GIT_AUTHOR_EMAIL='${email}'
        export GIT_COMMITTER_NAME='${fullName}'
        export GIT_COMMITTER_EMAIL='${email}'
        export GIT_SSH_COMMAND='${pkgs.openssh}/bin/ssh -o BatchMode=yes -o StrictHostKeyChecking=no'
        cd ${flakeDir}
        echo '$PASSPHRASE' | ${pkgs.sshpass}/bin/sshpass -p '$PASSPHRASE' -P 'passphrase' \
          ${pkgs.git}/bin/git commit -m 'flake: update inputs'
      "

      LATEST_HASH=$($GIT_AS_USER "${pkgs.git}/bin/git -C ${flakeDir} rev-parse HEAD")
      log_info "New commit created: ''${LATEST_HASH:0:7}"

      # Verify the commit author
      COMMIT_AUTHOR=$($GIT_AS_USER "${pkgs.git}/bin/git -C ${flakeDir} log -1 --format='%an <%ae>'")
      log_info "Commit author: $COMMIT_AUTHOR"

      log_success "Commit signature will be verified by secure-rebuild."

      log_info "Building new system generation and setting it as default for next boot..."
      if /run/current-system/sw/bin/secure-rebuild "$LATEST_HASH" boot; then
        log_success "System build complete."
        write_result "success:updated"
        UPGRADE_SUCCESS=1
      else
        log_error "System build failed"
        write_result "error:build_failed"
        wait $FLATPAK_PID || true
        cleanup_and_exit 1
      fi
    else
      log_error "SECURITY ABORT: Unexpected changes detected!"
      log_error "The following files were modified: $GIT_STATUS"
      write_result "error:unexpected_changes"
      wait $FLATPAK_PID || true
      cleanup_and_exit 1
    fi

    # Maintenance tasks. Some run on every shutdown, some only on update.
    if [ "$FINAL_ACTION" = "shutdown" ]; then
      log_header "Running Maintenance Tasks"

      # 1. Flatpak updates: This will run on EVERY shutdown.
      log_info "Waiting for Flatpak updates to complete..."
      wait $FLATPAK_PID || true
      if [ -f /tmp/flatpak-update.log ]; then
        cat /tmp/flatpak-update.log
        rm -f /tmp/flatpak-update.log
      fi
      log_success "Flatpak maintenance complete."

      # 2. Nix maintenance: This will ONLY run if the flake was actually updated.
      if [ "$GIT_STATUS" = "$EXPECTED_STATUS" ]; then
        log_info "Flake was updated, running Nix-specific maintenance..."

        log_info "Cleaning system and user generations..."
        ${pkgs.nh}/bin/nh clean all --keep 5

        log_info "Optimizing Nix store..."
        ${pkgs.nix}/bin/nix store optimise

        log_success "Nix-specific maintenance complete."
      else
        log_info "Flake was not updated, skipping Nix-specific maintenance."
      fi
    else
      # For reboot or if the upgrade process failed, just wait for the background Flatpak process to finish.
      wait $FLATPAK_PID || true
    fi

    log_success "All tasks concluded."

    # Perform the final action (shutdown/reboot)
    cleanup_and_exit 0
  '';

  # Notification script
  notifyUpgradeResult = pkgs.writeShellScript "notify-upgrade-result" ''
    #!${pkgs.bash}/bin/bash
    RESULT_FILE="${upgradeResultFile}"

    if [ ! -f "$RESULT_FILE" ]; then
      exit 0
    fi

    RESULT=$(cat "$RESULT_FILE")
    rm -f "$RESULT_FILE"

    # Wait for graphical session
    sleep 5

    case "$RESULT" in
      success:updated)
        ${pkgs.libnotify}/bin/notify-send -u normal -t 10000 \
          "System Upgrade Successful" \
          "System was successfully updated and is now running the new configuration."
        ;;
      success:no_updates)
        ${pkgs.libnotify}/bin/notify-send -u low -t 5000 \
          "System Already Up-to-date" \
          "No updates were available during the last upgrade attempt."
        ;;
      error:dirty_repo)
        ${pkgs.libnotify}/bin/notify-send -u critical -t 0 \
          "⚠️ Upgrade Failed: Dirty Repository" \
          "The git repository had uncommitted changes. Please commit or stash changes before upgrading."
        ;;
      error:battery_low:*)
        LEVEL=''${RESULT##*:}
        ${pkgs.libnotify}/bin/notify-send -u critical -t 0 \
          "⚠️ Upgrade Failed: Low Battery" \
          "Battery level was $LEVEL% (minimum ${toString batteryThreshold}% required). Please charge before upgrading."
        ;;
      error:build_failed)
        ${pkgs.libnotify}/bin/notify-send -u critical -t 0 \
          "⚠️ Upgrade Failed: Build Error" \
          "The system build failed. Check logs for details."
        ;;
      error:unexpected_changes)
        ${pkgs.libnotify}/bin/notify-send -u critical -t 0 \
          "⚠️ Upgrade Failed: Security Check" \
          "Unexpected file changes detected in repository. Manual intervention required."
        ;;
      error:*)
        ${pkgs.libnotify}/bin/notify-send -u critical -t 0 \
          "⚠️ Upgrade Failed" \
          "An error occurred during system upgrade. Check logs for details."
        ;;
    esac
  '';
in {
  programs.nh.enable = true;
  programs.git.enable = true;

  systemd.services = {
    "upgrade-and-reboot" = {
      description = "Perform a system upgrade and then reboot";
      conflicts = ["display-manager.service"];
      serviceConfig = {
        Type = "oneshot";
        StandardInput = "tty";
        StandardOutput = "tty";
        StandardError = "tty";
        TTYPath = "/dev/tty1";
        Environment = "PATH=${pkgs.git}/bin:${pkgs.sshpass}/bin:${pkgs.openssh}/bin:${pkgs.ncurses}/bin:${pkgs.sway}/bin:${pkgs.flatpak}/bin:${pkgs.nix-index}/bin:${pkgs.nix}/bin:${pkgs.curl}/bin:${pkgs.jq}/bin:${pkgs.bc}/bin:${pkgs.gnused}/bin:${pkgs.kbd}/bin:${pkgs.su}/bin:${pkgs.ripgrep}/bin:/run/current-system/sw/bin";
        ExecStart = "${upgradeAndPowerOffWorker} reboot";
        User = "root";
        Group = "root";
      };
    };

    "upgrade-and-shutdown" = {
      description = "Perform a system upgrade and then shut down";
      conflicts = ["display-manager.service"];
      serviceConfig = {
        Type = "oneshot";
        StandardInput = "tty";
        StandardOutput = "tty";
        StandardError = "tty";
        TTYPath = "/dev/tty1";
        Environment = "PATH=${pkgs.git}/bin:${pkgs.sshpass}/bin:${pkgs.openssh}/bin:${pkgs.ncurses}/bin:${pkgs.sway}/bin:${pkgs.flatpak}/bin:${pkgs.nix-index}/bin:${pkgs.nix}/bin:${pkgs.curl}/bin:${pkgs.jq}/bin:${pkgs.bc}/bin:${pkgs.gnused}/bin:${pkgs.kbd}/bin:${pkgs.su}/bin:${pkgs.ripgrep}/bin:/run/current-system/sw/bin";
        ExecStart = "${upgradeAndPowerOffWorker} shutdown";
        User = "root";
        Group = "root";
      };
    };

    # Notification service that runs on boot
    "upgrade-result-notifier" = {
      description = "Notify user of upgrade results from previous boot";
      after = ["graphical-session.target"];
      wantedBy = ["graphical-session.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${notifyUpgradeResult}";
        User = username;
        RemainAfterExit = false;
      };
    };
  };

  # Create state directory
  systemd.tmpfiles.rules = [
    "d /var/lib/upgrade-service 0755 root root -"
  ];

  security.sudo-rs.extraRules = [
    {
      users = [username];
      commands = [
        {
          command = "${pkgs.systemd}/bin/systemctl start upgrade-and-reboot.service";
          options = ["NOPASSWD"];
        }
        {
          command = "${pkgs.systemd}/bin/systemctl start upgrade-and-shutdown.service";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  home-manager.users.${username} = {
    wayland.windowManager.sway.config.keybindings = {
      "mod4+Mod1+Shift+r" = "exec upgrade-and-reboot";
      "mod4+Mod1+Shift+p" = "exec upgrade-and-shutdown";
    };
  };

  environment.systemPackages = [
    (pkgs.writeShellApplication {
      name = "upgrade-and-reboot";
      runtimeInputs = [pkgs.systemd];
      text = "sudo systemctl start upgrade-and-reboot.service";
    })
    (pkgs.writeShellApplication {
      name = "upgrade-and-shutdown";
      runtimeInputs = [pkgs.systemd];
      text = "sudo systemctl start upgrade-and-shutdown.service";
    })
  ];
}
