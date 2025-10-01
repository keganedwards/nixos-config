{
  pkgs,
  config,
  username,
  fullName,
  email,
  flakeDir,
  ...
}: let
  helpers = import ./helpers.nix {
    inherit pkgs config username fullName email;
  };

  sshPassphraseFile = config.sops.secrets."ssh-key-passphrase".path;
  upgradeResultFile = "/var/lib/upgrade-service/last-result";
  batteryThreshold = 30;

  upgradeAndPowerOffWorker = pkgs.writeShellScript "system-upgrade-worker" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    FINAL_ACTION=$1
    RESULT_FILE="${upgradeResultFile}"
    UPGRADE_SUCCESS=0

    # These variables need to be available for the maintenance check later
    GIT_STATUS=""
    EXPECTED_STATUS=" M flake.lock"

    ${helpers.loggingHelpers}

    # Function to write result for notification service
    write_result() {
      mkdir -p $(dirname "$RESULT_FILE")
      echo "$1" > "$RESULT_FILE"
    }

    # Function to push to git
    push_to_git() {
      if [ $UPGRADE_SUCCESS -eq 1 ]; then
        log_info "Pushing flake.lock to remote repository..."

        if ${helpers.gitSshHelper} push "${flakeDir}" origin main; then
          log_success "Successfully pushed to remote."
        else
          log_error "Failed to push to remote."
        fi
      fi
    }

    perform_final_action() {
      # Push to git if the upgrade was successful
      push_to_git

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

    cleanup_and_exit() {
      local exit_code=$1
      if [ $exit_code -ne 0 ]; then
        log_error "Upgrade failed with error code $exit_code"
      fi
      perform_final_action
      exit $exit_code
    }

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
        API_KEY=$(${pkgs.gnused}/bin/sed -n 's/.*<apikey>\(.*\)<\/apikey>.*/\1/p' /home/${username}/.config/syncthing/config.xml 2>/dev/null || echo "")

        if [ -z "$API_KEY" ]; then
          log_info "Unable to read Syncthing API key - proceeding anyway"
          break
        fi

        SYNC_STATUS=$(${pkgs.curl}/bin/curl -s http://localhost:8384/rest/db/completion \
          -H "X-API-Key: $API_KEY" 2>/dev/null || echo "")

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

    turn_off_screen() {
      log_info "Turning off display..."

      ${pkgs.kbd}/bin/setterm -blank force -powersave on > /dev/tty1 2>/dev/null || true
    }

    # Main upgrade logic starts here
    clear
    log_header "System Upgrade Service Started"

    # Perform battery check first
    if ! check_battery; then
      cleanup_and_exit 1
    fi

    # Kill Brave BEFORE exiting sway - run as user
    log_info "Killing Brave browser..."
    ${pkgs.sudo}/bin/sudo -u ${username} ${pkgs.flatpak}/bin/flatpak kill com.brave.Browser 2>/dev/null || true

    # Wait for Brave to fully close
    for i in {1..20}; do
      if ! ${pkgs.sudo}/bin/sudo -u ${username} ${pkgs.flatpak}/bin/flatpak ps --columns=application 2>/dev/null | ${pkgs.ripgrep}/bin/rg -q "com.brave.Browser"; then
        log_success "Brave closed successfully"
        break
      fi
      sleep 0.1
    done

    # Exit sway session - don't wait for it
    log_info "Closing graphical session..."
    ${pkgs.sudo}/bin/sudo -u ${username} ${pkgs.sway}/bin/swaymsg exit 2>/dev/null || true

    # Start flatpak operations early in parallel
    log_info "Starting Flatpak updates in background..."
    (
      # Update system-level flatpaks as root
      ${pkgs.flatpak}/bin/flatpak update --system -y 2>&1 | tee /tmp/flatpak-update.log || true
      ${pkgs.flatpak}/bin/flatpak uninstall --system --unused -y 2>&1 | tee -a /tmp/flatpak-update.log || true
    ) &
    FLATPAK_PID=$!

    cd ${flakeDir} || {
      log_error "Failed to change directory to ${flakeDir}"
      write_result "error:cd_failed"
      cleanup_and_exit 1
    }

    log_info "Verifying repository is in a clean state..."
    # Run git commands as the repo owner with explicit safe directory
    if ! ${pkgs.sudo}/bin/sudo -u ${username} ${pkgs.git}/bin/git -c safe.directory=${flakeDir} -C ${flakeDir} diff --quiet HEAD --; then
      log_error "Git repository is dirty. Aborting upgrade."
      write_result "error:dirty_repo"
      wait $FLATPAK_PID || true
      cleanup_and_exit 1
    fi
    log_success "Repository is clean."

    log_info "Updating flake inputs..."
    ${pkgs.sudo}/bin/sudo -u ${username} ${pkgs.nix}/bin/nix flake update --flake ${flakeDir}

    GIT_STATUS=$(${pkgs.sudo}/bin/sudo -u ${username} ${pkgs.git}/bin/git -c safe.directory=${flakeDir} -C ${flakeDir} status --porcelain)

    if [ -z "$GIT_STATUS" ]; then
      log_info "No changes detected after update. System is already up-to-date."
      write_result "success:no_updates"
      UPGRADE_SUCCESS=1
    elif [ "$GIT_STATUS" = "$EXPECTED_STATUS" ]; then
      log_success "Verified: Only flake.lock was modified. Proceeding."

      ${pkgs.sudo}/bin/sudo -u ${username} ${pkgs.git}/bin/git -c safe.directory=${flakeDir} -C ${flakeDir} add flake.lock

      log_info "Committing flake.lock..."
      # Use gitSshHelper for commit with SSH agent
      if ! ${helpers.gitSshHelper} commit "${flakeDir}" -m "flake: update inputs"; then
        log_error "Failed to commit changes"
        write_result "error:commit_failed"
        wait $FLATPAK_PID || true
        cleanup_and_exit 1
      fi

      LATEST_HASH=$(${pkgs.sudo}/bin/sudo -u ${username} ${pkgs.git}/bin/git -c safe.directory=${flakeDir} -C ${flakeDir} rev-parse HEAD)
      log_info "New commit created: ''${LATEST_HASH:0:7}"

      # Verify the commit author
      COMMIT_AUTHOR=$(${pkgs.sudo}/bin/sudo -u ${username} ${pkgs.git}/bin/git -c safe.directory=${flakeDir} -C ${flakeDir} log -1 --format='%an <%ae>')
      log_info "Commit author: $COMMIT_AUTHOR"

      log_success "Commit signature will be verified by secure-rebuild."

      log_info "Building new system generation and setting it as default for next boot..."
      # secure-rebuild is designed to run as root, which is the default user for this script.
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

    # Maintenance tasks
    if [ "$FINAL_ACTION" = "shutdown" ]; then
      log_header "Running Maintenance Tasks"

      log_info "Waiting for Flatpak updates to complete..."
      wait $FLATPAK_PID || true
      if [ -f /tmp/flatpak-update.log ]; then
        cat /tmp/flatpak-update.log
        rm -f /tmp/flatpak-update.log
      fi
      log_success "Flatpak maintenance complete."

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
      wait $FLATPAK_PID || true
    fi

    log_success "All tasks concluded."

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

    # Wait for graphical environment to be ready
    for i in {1..30}; do
      if [ -n "$WAYLAND_DISPLAY" ] || [ -n "$DISPLAY" ]; then
        break
      fi
      sleep 1
    done

    # Verify we have a display
    if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ]; then
      echo "No graphical environment detected, skipping notification"
      exit 0
    fi

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
      error:commit_failed)
        ${pkgs.libnotify}/bin/notify-send -u critical -t 0 \
          "⚠️ Upgrade Failed: Commit Error" \
          "Failed to commit changes. Check logs for details."
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

    rm -f "$RESULT_FILE"
  '';
in {
  programs = {
    nh.enable = true;
    git.enable = true;
  };

  systemd = {
    services = {
      "upgrade-and-reboot" = {
        description = "Perform a system upgrade and then reboot";
        conflicts = ["display-manager.service"];
        serviceConfig = {
          Type = "oneshot";
          StandardOutput = "journal+console";
          StandardError = "journal+console";
          TTYPath = "/dev/tty1";
          Environment = "PATH=${pkgs.coreutils}/bin:${pkgs.git}/bin:${pkgs.openssh}/bin:${pkgs.ncurses}/bin:${pkgs.sway}/bin:${pkgs.flatpak}/bin:${pkgs.nix-index}/bin:${pkgs.nix}/bin:${pkgs.curl}/bin:${pkgs.jq}/bin:${pkgs.bc}/bin:${pkgs.gnused}/bin:${pkgs.kbd}/bin:${pkgs.sudo}/bin:${pkgs.ripgrep}/bin:${pkgs.procps}/bin:${pkgs.expect}/bin:${pkgs.bash}/bin:/run/current-system/sw/bin";
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
          StandardOutput = "journal+console";
          StandardError = "journal+console";
          TTYPath = "/dev/tty1";
          Environment = "PATH=${pkgs.coreutils}/bin:${pkgs.git}/bin:${pkgs.openssh}/bin:${pkgs.ncurses}/bin:${pkgs.sway}/bin:${pkgs.flatpak}/bin:${pkgs.nix-index}/bin:${pkgs.nix}/bin:${pkgs.curl}/bin:${pkgs.jq}/bin:${pkgs.bc}/bin:${pkgs.gnused}/bin:${pkgs.kbd}/bin:${pkgs.sudo}/bin:${pkgs.ripgrep}/bin:${pkgs.procps}/bin:${pkgs.expect}/bin:${pkgs.bash}/bin:/run/current-system/sw/bin";
          ExecStart = "${upgradeAndPowerOffWorker} shutdown";
          User = "root";
          Group = "root";
        };
      };
    };

    user.services."upgrade-result-notifier" = {
      description = "Notify user of upgrade results from previous boot";
      wantedBy = ["graphical-session.target"];
      after = ["graphical-session.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${notifyUpgradeResult}";
        RemainAfterExit = false;
      };
    };

    tmpfiles.rules = [
      "d /var/lib/upgrade-service 0755 root root -"
    ];
  };

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
