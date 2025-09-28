{
  pkgs,
  config,
  username,
  flakeDir,
  ...
}: let
  sshPassphraseFile = config.sops.secrets."ssh-key-passphrase".path;
  dotfilesDir = "/home/${username}/.dotfiles";
  stateDir = "/var/lib/boot-update";
  statusFile = "${stateDir}/last-update-status";

  # Script to check if we're in early boot (uptime < 30 seconds)
  uptimeCheck = pkgs.writeShellScript "uptime-check" ''
    UPTIME_SECONDS=$(${pkgs.coreutils}/bin/cut -d. -f1 /proc/uptime)
    if [ "$UPTIME_SECONDS" -ge 30 ]; then
      exit 1
    fi
    exit 0
  '';

  bootUpdateWorker = pkgs.writeShellScript "boot-update-worker" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    log_header()  { echo -e "\n\e[1;35m--- $1 ---\e[0m"; }
    log_info()    { echo -e "\e[34m[INFO]\e[0m $1"; }
    log_success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
    log_error()   { echo -e "\e[1;31m[ERROR]\e[0m $1"; }
    log_warning() { echo -e "\e[33m[WARNING]\e[0m $1"; }

    # Start by logging only to journal (silent, no TTY switch)
    exec 1> >(${pkgs.systemd}/bin/systemd-cat -t boot-update) 2>&1

    log_info "Boot Update Service Starting (silent mode)"

    # Check if we already ran this boot session
    BOOT_ID=$(${pkgs.coreutils}/bin/cat /proc/sys/kernel/random/boot_id)
    BOOT_FLAG="/run/boot-update-ran-$BOOT_ID"

    if [ -f "$BOOT_FLAG" ]; then
      log_success "Already ran for this boot session. Skipping."
      exit 0
    fi

    # Mark that we're running for this boot
    ${pkgs.coreutils}/bin/touch "$BOOT_FLAG"

    # Create state directory
    ${pkgs.coreutils}/bin/mkdir -p ${stateDir}

    # Wait for network
    log_info "Waiting for network connectivity..."
    for i in {1..30}; do
      if ${pkgs.iputils}/bin/ping -c 1 -W 2 github.com &> /dev/null; then
        log_success "Network is available."
        break
      fi
      if [ $i -eq 30 ]; then
        log_error "Network not available after 30 seconds. Skipping update."
        echo "NETWORK_FAILED" > ${statusFile}
        exit 0
      fi
      sleep 1
    done

    NEEDS_REBOOT=false
    SYSTEM_UPDATED=false
    FLATPAK_UPDATED=false
    export HOME="/home/${username}"
    export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i /home/${username}/.ssh/id_ed25519 -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/home/${username}/.ssh/known_hosts"
    PASSPHRASE=$(cat ${sshPassphraseFile})

    # ===== UPDATE SYSTEM FLAKE =====
    log_info "Checking system configuration repository"

    cd "${flakeDir}" || {
      log_error "Failed to change directory to ${flakeDir}"
      echo "ERROR|Failed to access system configuration" > ${statusFile}
      exit 0
    }
    GIT_CMD="${pkgs.git}/bin/git -c safe.directory=${flakeDir}"

    log_info "Verifying repository is in a clean state..."
    if ! runuser -u ${username} -- $GIT_CMD diff --quiet HEAD --; then
      log_error "Git repository is dirty. Skipping system update."
      echo "DIRTY_REPO" > ${statusFile}
    else
      log_success "Repository is clean."

      log_info "Fetching upstream changes..."
      if ! runuser -u ${username} -p -- \
          ${pkgs.sshpass}/bin/sshpass -p "$PASSPHRASE" -P "passphrase" \
          $GIT_CMD fetch origin; then
        log_error "Failed to fetch from upstream."
        echo "FETCH_FAILED" > ${statusFile}
      else
        COMMITS_BEHIND=$(runuser -u ${username} -- $GIT_CMD rev-list --count HEAD..origin/main)

        if [ "$COMMITS_BEHIND" -eq 0 ]; then
          log_success "System is up to date or ahead of origin/main. No system update needed."
        else
          # Switch to visible TTY mode and stop display manager
          log_warning "System updates detected! Switching to visible update mode..."

          # Stop display manager
          ${pkgs.systemd}/bin/systemctl stop display-manager.service 2>/dev/null || true
          sleep 2

          # Redirect output to TTY1 for visibility
          exec > >(${pkgs.coreutils}/bin/tee /dev/tty1 >(${pkgs.systemd}/bin/systemd-cat -t boot-update)) 2>&1

          log_header "System Updates Available"
          log_info "Upstream changes detected ($COMMITS_BEHIND commits behind). Pulling changes..."

          if ! runuser -u ${username} -p -- \
              ${pkgs.sshpass}/bin/sshpass -p "$PASSPHRASE" -P "passphrase" \
              $GIT_CMD pull origin main; then
            log_error "Failed to pull changes from upstream."
            echo "PULL_FAILED" > ${statusFile}
            exit 0
          else
            NEW_COMMIT=$(runuser -u ${username} -- $GIT_CMD rev-parse HEAD)
            log_success "Successfully pulled changes. New commit: ''${NEW_COMMIT:0:7}"

            log_info "Updating flake inputs..."
            runuser -u ${username} -- ${pkgs.nix}/bin/nix flake update

            GIT_STATUS=$(runuser -u ${username} -- $GIT_CMD status --porcelain)

            if [ -n "$GIT_STATUS" ]; then
              EXPECTED_STATUS=" M flake.lock"
              if [ "$GIT_STATUS" = "$EXPECTED_STATUS" ]; then
                log_success "Verified: Only flake.lock was modified. Proceeding."

                runuser -u ${username} -- $GIT_CMD add flake.lock
                log_info "Committing flake.lock...";
                runuser -u ${username} -p -- \
                  ${pkgs.sshpass}/bin/sshpass -p "$PASSPHRASE" -P "passphrase" \
                  $GIT_CMD commit -m "flake: update inputs"

                log_info "Pushing changes to upstream..."
                if ! runuser -u ${username} -p -- \
                    ${pkgs.sshpass}/bin/sshpass -p "$PASSPHRASE" -P "passphrase" \
                    $GIT_CMD push origin main; then
                  log_error "Failed to push flake.lock changes."
                  echo "PUSH_FAILED" > ${statusFile}
                  exit 0
                fi

                LATEST_HASH=$(runuser -u ${username} -- $GIT_CMD rev-parse HEAD)
                log_success "Changes committed and pushed: ''${LATEST_HASH:0:7}"
              else
                log_error "SECURITY ABORT: Unexpected changes detected!"
                log_error "The following files were modified: $GIT_STATUS"
                echo "SECURITY_ABORT|Unexpected file changes" > ${statusFile}
                exit 0
              fi
            fi

            log_info "Building new system generation..."
            if ! /run/current-system/sw/bin/secure-rebuild "$NEW_COMMIT" boot; then
              log_error "System rebuild failed."
              echo "BUILD_FAILED" > ${statusFile}
              exit 0
            fi

            log_success "System rebuild complete."
            SYSTEM_UPDATED=true
            NEEDS_REBOOT=true
          fi
        fi
      fi
    fi

    # ===== UPDATE DOTFILES =====
    log_info "Checking dotfiles repository"

    if [ -d "${dotfilesDir}" ]; then
      cd "${dotfilesDir}" || { log_error "Failed to change directory to ${dotfilesDir}"; }
      DOTFILES_CMD="${pkgs.git}/bin/git -c safe.directory=${dotfilesDir}"

      log_info "Verifying dotfiles repository state..."
      if ! runuser -u ${username} -- $DOTFILES_CMD diff --quiet HEAD --; then
        log_warning "Dotfiles repository has local changes. Stashing them..."
        runuser -u ${username} -- $DOTFILES_CMD stash
      fi

      log_info "Fetching dotfiles updates..."
      if ! runuser -u ${username} -p -- \
          ${pkgs.sshpass}/bin/sshpass -p "$PASSPHRASE" -P "passphrase" \
          $DOTFILES_CMD fetch origin; then
        log_error "Failed to fetch dotfiles from upstream."
      else
        DOTFILES_COMMITS_BEHIND=$(runuser -u ${username} -- $DOTFILES_CMD rev-list --count HEAD..origin/main)

        if [ "$DOTFILES_COMMITS_BEHIND" -eq 0 ]; then
          log_success "Dotfiles are up to date or ahead of origin/main."
        else
          log_info "Dotfiles have upstream changes. Resetting to match remote..."
          runuser -u ${username} -- $DOTFILES_CMD reset --hard origin/main
          DOTFILES_NEW=$(runuser -u ${username} -- $DOTFILES_CMD rev-parse HEAD)
          log_success "Dotfiles updated to: ''${DOTFILES_NEW:0:7}"
        fi
      fi
    else
      log_warning "Dotfiles directory not found at ${dotfilesDir}"
    fi

    # ===== UPDATE FLATPAKS =====
    log_info "Checking for Flatpak updates..."

    if command -v ${pkgs.flatpak}/bin/flatpak >/dev/null 2>&1; then
      # Check if there are flatpak updates available
      FLATPAK_UPDATES=$(runuser -u ${username} -- ${pkgs.flatpak}/bin/flatpak remote-ls --updates 2>/dev/null | wc -l)

      if [ "$FLATPAK_UPDATES" -gt 0 ]; then
        log_info "Found $FLATPAK_UPDATES Flatpak updates. Applying..."

        if runuser -u ${username} -- ${pkgs.flatpak}/bin/flatpak update -y; then
          log_success "Flatpak updates completed successfully."
          FLATPAK_UPDATED=true
        else
          log_warning "Some Flatpak updates may have failed."
        fi
      else
        log_success "All Flatpaks are up to date."
      fi
    else
      log_info "Flatpak not installed, skipping Flatpak updates."
    fi

    # ===== SAVE STATUS AND REBOOT IF NEEDED =====
    if [ "$SYSTEM_UPDATED" = true ]; then
      # Save success status BEFORE rebooting
      echo "SYSTEM_SUCCESS|System updated to ''${NEW_COMMIT:0:7}" > ${statusFile}
      log_header "System updated successfully. Rebooting now..."
      ${pkgs.systemd}/bin/systemctl reboot
    elif [ "$FLATPAK_UPDATED" = true ]; then
      # Only flatpaks were updated
      echo "FLATPAK_SUCCESS|Flatpak applications updated" > ${statusFile}
      log_success "Flatpak updates complete. No reboot required."
    else
      # Nothing was updated
      echo "UP_TO_DATE|No updates were needed" > ${statusFile}
      log_success "All updates complete. No reboot required."
    fi

    exit 0
  '';

  # Script to show notification on next boot
  showBootUpdateNotification = pkgs.writeShellScript "show-boot-update-notification" ''
    #!${pkgs.bash}/bin/bash

    if [ ! -f "${statusFile}" ]; then
      exit 0
    fi

    STATUS=$(${pkgs.coreutils}/bin/cat ${statusFile})

    export DISPLAY=:0
    export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(${pkgs.coreutils}/bin/id -u ${username})/bus

    case "$STATUS" in
      UP_TO_DATE*)
        ${pkgs.libnotify}/bin/notify-send -u normal -t 5000 \
          "✅ System Update Check" \
          "🎯 System is up to date. No updates were needed."
        ;;
      SYSTEM_SUCCESS*)
        COMMIT=$(echo "$STATUS" | ${pkgs.coreutils}/bin/cut -d'|' -f2)
        ${pkgs.libnotify}/bin/notify-send -u normal -t 10000 \
          "🎉 System Updated Successfully" \
          "🔄 $COMMIT\n\n💻 System was updated and rebooted."
        ;;
      FLATPAK_SUCCESS*)
        ${pkgs.libnotify}/bin/notify-send -u normal -t 8000 \
          "📦 Flatpak Updates Applied" \
          "✨ Flatpak applications have been updated successfully."
        ;;
      NETWORK_FAILED)
        ${pkgs.libnotify}/bin/notify-send -u critical -t 10000 \
          "🌐 Update Check Failed" \
          "❌ Network was not available during boot update check."
        ;;
      DIRTY_REPO)
        ${pkgs.libnotify}/bin/notify-send -u critical -t 10000 \
          "⚠️ Update Check Skipped" \
          "📝 System repository has uncommitted changes."
        ;;
      FETCH_FAILED)
        ${pkgs.libnotify}/bin/notify-send -u critical -t 10000 \
          "🔍 Update Check Failed" \
          "❌ Failed to fetch updates from remote repository."
        ;;
      PULL_FAILED)
        ${pkgs.libnotify}/bin/notify-send -u critical -t 10000 \
          "⬇️ Update Failed" \
          "❌ Failed to pull changes from remote repository."
        ;;
      PUSH_FAILED)
        ${pkgs.libnotify}/bin/notify-send -u critical -t 10000 \
          "⬆️ Update Failed" \
          "❌ Failed to push flake.lock updates to remote."
        ;;
      BUILD_FAILED)
        ${pkgs.libnotify}/bin/notify-send -u critical -t 10000 \
          "🔨 System Build Failed" \
          "❌ Failed to rebuild system with new configuration."
        ;;
      SECURITY_ABORT*)
        ${pkgs.libnotify}/bin/notify-send -u critical -t 15000 \
          "🚨 Security Abort" \
          "🛑 Update aborted due to unexpected file changes."
        ;;
      ERROR*)
        MSG=$(echo "$STATUS" | ${pkgs.coreutils}/bin/cut -d'|' -f2)
        ${pkgs.libnotify}/bin/notify-send -u critical -t 10000 \
          "💥 Update Error" \
          "❌ $MSG"
        ;;
    esac

    # Clear status file after showing notification
    rm -f ${statusFile}
  '';

  cancelBootUpdate = pkgs.writeShellScriptBin "cancel-boot-update" ''
    #!${pkgs.bash}/bin/bash
    echo "Stopping boot update service..."
    sudo systemctl stop boot-update.service
    echo "Service stopped. Starting display manager..."
    sudo systemctl start display-manager.service
  '';

  resetBootUpdateMarker = pkgs.writeShellScriptBin "reset-boot-update-marker" ''
    #!${pkgs.bash}/bin/bash
    echo "Clearing boot update flag for this session..."
    BOOT_ID=$(cat /proc/sys/kernel/random/boot_id)
    sudo rm -f "/run/boot-update-ran-$BOOT_ID"
    echo "Flag cleared. Service can run again this boot."
  '';
in {
  programs.nh.enable = true;
  programs.git.enable = true;

  # Create persistent state directory
  systemd.tmpfiles.rules = [
    "d ${stateDir} 0755 root root -"
  ];

  systemd.services."boot-update" = {
    description = "Check for upstream changes and update system on boot";

    wantedBy = ["multi-user.target"];
    after = ["network-online.target"];
    wants = ["network-online.target"];

    restartIfChanged = false;
    reloadIfChanged = false;

    unitConfig = {
      ConditionPathExistsGlob = "!/run/boot-update-ran-*";
    };

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;

      ExecCondition = "${uptimeCheck}";
      ExecStart = "${bootUpdateWorker}";

      Environment = "PATH=${pkgs.git}/bin:${pkgs.sshpass}/bin:${pkgs.openssh}/bin:${pkgs.nix}/bin:${pkgs.iputils}/bin:${pkgs.coreutils}/bin:${pkgs.flatpak}/bin:/run/current-system/sw/bin";

      User = "root";
      Group = "root";

      StandardOutput = "journal";
      StandardError = "journal";

      TimeoutStartSec = "1800";

      KillMode = "mixed";
      KillSignal = "SIGTERM";
    };
  };

  # Show notification after user logs in
  systemd.user.services."boot-update-notification" = {
    description = "Show boot update result notification";

    wantedBy = ["graphical-session.target"];
    after = ["graphical-session.target"];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${showBootUpdateNotification}";
      RemainAfterExit = false;
    };
  };

  security.sudo-rs.extraRules = [
    {
      users = [username];
      commands = [
        {
          command = "${pkgs.systemd}/bin/systemctl stop boot-update.service";
          options = ["NOPASSWD"];
        }
        {
          command = "${pkgs.systemd}/bin/systemctl start display-manager.service";
          options = ["NOPASSWD"];
        }
        {
          command = "${pkgs.coreutils}/bin/rm -f /run/boot-update-ran-*";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  environment.systemPackages = [
    cancelBootUpdate
    resetBootUpdateMarker
  ];
}
