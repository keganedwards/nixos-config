{
  pkgs,
  config,
  username,
  flakeDir,
  ...
}: let
  sshPassphraseFile = config.sops.secrets."ssh-key-passphrase".path;
  dotfilesDir = "/home/${username}/.dotfiles";

  bootUpdateWorker = pkgs.writeShellScript "boot-update-worker" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    log_header()  { echo -e "\n\e[1;35m--- $1 ---\e[0m"; }
    log_info()    { echo -e "\e[34m[INFO]\e[0m $1"; }
    log_success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
    log_error()   { echo -e "\e[1;31m[ERROR]\e[0m $1"; }
    log_warning() { echo -e "\e[33m[WARNING]\e[0m $1"; }

    # CRITICAL: Verify we're actually in boot (not a service restart)
    BOOT_ID=$(cat /proc/sys/kernel/random/boot_id)
    MARKER_FILE="/var/lib/boot-update-tracker"

    if [ -f "$MARKER_FILE" ]; then
      LAST_BOOT_ID=$(cat "$MARKER_FILE")
      if [ "$BOOT_ID" = "$LAST_BOOT_ID" ]; then
        log_info "Already ran this boot session. Exiting."
        exit 0
      fi
    fi

    # Stop the display manager IMMEDIATELY to prevent logins
    log_header "Stopping login manager to prevent user access during update"
    DISPLAY_MANAGER="${config.services.xserver.displayManager.enable}"
    DM_SERVICE=""

    # Detect which display manager is running
    if systemctl is-active --quiet sddm.service; then
      DM_SERVICE="sddm.service"
    elif systemctl is-active --quiet gdm.service; then
      DM_SERVICE="gdm.service"
    elif systemctl is-active --quiet lightdm.service; then
      DM_SERVICE="lightdm.service"
    fi

    if [ -n "$DM_SERVICE" ]; then
      log_info "Stopping $DM_SERVICE..."
      systemctl stop "$DM_SERVICE"
      log_success "Login manager stopped."
    fi

    # Switch to TTY1 for visible output
    ${pkgs.kbd}/bin/chvt 1

    # Clear screen and show prominent message
    clear
    cat << 'EOF'
    ╔══════════════════════════════════════════════════════════════╗
    ║                                                              ║
    ║          SYSTEM UPDATE IN PROGRESS - PLEASE WAIT            ║
    ║                                                              ║
    ║              DO NOT POWER OFF THE SYSTEM                    ║
    ║                                                              ║
    ╚══════════════════════════════════════════════════════════════╝
    EOF

    NEEDS_SHUTDOWN=false

    log_header "Boot Update Service - Checking for upstream changes"

    # Wait for network to be available
    log_info "Waiting for network connectivity..."
    for i in {1..30}; do
      if ${pkgs.iputils}/bin/ping -c 1 -W 2 github.com &> /dev/null; then
        log_success "Network is available."
        break
      fi
      if [ $i -eq 30 ]; then
        log_error "Network not available after 30 seconds. Skipping update."
        # Restart display manager before exiting
        [ -n "$DM_SERVICE" ] && systemctl start "$DM_SERVICE"
        exit 0
      fi
      sleep 1
    done

    export HOME="/home/${username}"
    export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i /home/${username}/.ssh/id_ed25519 -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/home/${username}/.ssh/known_hosts"
    PASSPHRASE=$(cat ${sshPassphraseFile})

    # ===== UPDATE SYSTEM FLAKE =====
    log_header "Checking system configuration repository"

    cd "${flakeDir}" || { log_error "Failed to change directory to ${flakeDir}"; [ -n "$DM_SERVICE" ] && systemctl start "$DM_SERVICE"; exit 0; }
    GIT_CMD="${pkgs.git}/bin/git -c safe.directory=${flakeDir}"

    log_info "Verifying repository is in a clean state..."
    if ! runuser -u ${username} -- $GIT_CMD diff --quiet HEAD --; then
      log_error "Git repository is dirty. Skipping system update."
    else
      log_success "Repository is clean."

      log_info "Fetching upstream changes..."
      if ! runuser -u ${username} -p -- \
          ${pkgs.sshpass}/bin/sshpass -p "$PASSPHRASE" -P "passphrase" \
          $GIT_CMD fetch origin; then
        log_error "Failed to fetch from upstream."
      else
        COMMITS_BEHIND=$(runuser -u ${username} -- $GIT_CMD rev-list --count HEAD..origin/main)

        if [ "$COMMITS_BEHIND" -eq 0 ]; then
          log_success "System is up to date or ahead of origin/main. No update needed."
        else
          log_info "Upstream changes detected ($COMMITS_BEHIND commits behind). Pulling changes..."
          if ! runuser -u ${username} -p -- \
              ${pkgs.sshpass}/bin/sshpass -p "$PASSPHRASE" -P "passphrase" \
              $GIT_CMD pull origin main; then
            log_error "Failed to pull changes from upstream."
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
                runuser -u ${username} -p -- \
                  ${pkgs.sshpass}/bin/sshpass -p "$PASSPHRASE" -P "passphrase" \
                  $GIT_CMD push origin main

                LATEST_HASH=$(runuser -u ${username} -- $GIT_CMD rev-parse HEAD)
                log_success "Changes committed and pushed: ''${LATEST_HASH:0:7}"
              else
                log_error "SECURITY ABORT: Unexpected changes detected!"
                log_error "The following files were modified: $GIT_STATUS"
                [ -n "$DM_SERVICE" ] && systemctl start "$DM_SERVICE"
                exit 0
              fi
            fi

            log_info "Building new system generation..."
            /run/current-system/sw/bin/secure-rebuild "$NEW_COMMIT" boot
            log_success "System rebuild complete."
            NEEDS_SHUTDOWN=true
          fi
        fi
      fi
    fi

    # ===== UPDATE DOTFILES =====
    log_header "Checking dotfiles repository"

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

    # Mark this boot as completed
    echo "$BOOT_ID" > "$MARKER_FILE"

    # ===== SHUTDOWN IF NEEDED =====
    if [ "$NEEDS_SHUTDOWN" = true ]; then
      log_header "System updated successfully. Rebooting in 10 seconds..."
      log_warning "Press Ctrl+C to cancel reboot"
      sleep 10
      ${pkgs.systemd}/bin/systemctl reboot
    else
      log_success "All updates complete. No reboot required."
      log_info "Restarting login manager..."
      [ -n "$DM_SERVICE" ] && systemctl start "$DM_SERVICE"
    fi

    exit 0
  '';

  cancelBootUpdate = pkgs.writeShellScriptBin "cancel-boot-update" ''
    #!${pkgs.bash}/bin/bash
    echo "Stopping boot update service..."
    sudo systemctl stop boot-update.service
    echo "Service stopped. Restarting display manager..."
    sudo systemctl start display-manager.service 2>/dev/null || \
    sudo systemctl start sddm.service 2>/dev/null || \
    sudo systemctl start gdm.service 2>/dev/null || \
    sudo systemctl start lightdm.service 2>/dev/null
    echo "Done."
  '';
in {
  programs.nh.enable = true;
  programs.git.enable = true;

  # Create persistent directory for boot tracking
  systemd.tmpfiles.rules = [
    "d /var/lib 0755 root root -"
  ];

  systemd.services."boot-update" = {
    description = "Check for upstream changes and update system on boot";
    wantedBy = ["multi-user.target"];
    after = ["network-online.target" "multi-user.target"];
    wants = ["network-online.target"];
    before = ["display-manager.service"]; # Run BEFORE display manager starts

    # CRITICAL: These prevent re-running on config changes
    restartIfChanged = false;
    reloadIfChanged = false;
    stopIfChanged = false;

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
      Environment = "PATH=${pkgs.git}/bin:${pkgs.sshpass}/bin:${pkgs.openssh}/bin:${pkgs.ncurses}/bin:${pkgs.nix}/bin:${pkgs.iputils}/bin:${pkgs.kbd}/bin:/run/current-system/sw/bin";
      ExecStart = "${bootUpdateWorker}";
      User = "root";
      Group = "root";
      TimeoutStartSec = "1800";
      StandardOutput = "journal+console"; # Show output on console AND journal
      StandardError = "journal+console";
      TTYPath = "/dev/tty1"; # Output to TTY1
      TTYVTDisallocate = "no";
    };

    unitConfig = {
      # Double protection: check both boot ID and run flag
      ConditionPathExists = "!/run/systemd/boot-update-active";
      # Don't run if we're in rescue/emergency mode
      ConditionPathExists = "!/run/systemd/system/rescue.service";
    };
  };

  # Remove the separate marker service - we handle it internally now

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
          command = "${pkgs.systemd}/bin/systemctl start sddm.service";
          options = ["NOPASSWD"];
        }
        {
          command = "${pkgs.systemd}/bin/systemctl start gdm.service";
          options = ["NOPASSWD"];
        }
        {
          command = "${pkgs.systemd}/bin/systemctl start lightdm.service";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  environment.systemPackages = [cancelBootUpdate pkgs.kbd];
}
