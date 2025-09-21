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
    set -euo pipefail

    log_header()  { echo -e "\n\e[1;35m--- $1 ---\e[0m"; }
    log_info()    { echo -e "\e[34m[INFO]\e[0m $1"; }
    log_success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
    log_error()   { echo -e "\e[1;31m[ERROR]\e[0m $1"; }
    log_warning() { echo -e "\e[33m[WARNING]\e[0m $1"; }

    # Log to journal for debugging
    exec 2> >(${pkgs.systemd}/bin/systemd-cat -t boot-update)

    log_header "Boot Update Service Starting"

    # Check if we're in a nixos-rebuild - if so, exit immediately
    if [ -n "''${NIXOS_ACTION:-}" ] || [ -n "''${NIXOS_INSTALL_BOOTLOADER:-}" ]; then
      log_info "Running within nixos-rebuild context, skipping."
      exit 0
    fi

    # Use systemd's boot ID for more reliable boot detection
    CURRENT_BOOT_ID=$(cat /proc/sys/kernel/random/boot_id)
    MARKER_FILE="/var/lib/boot-update/last-boot-id"

    # Create directory if it doesn't exist
    ${pkgs.coreutils}/bin/mkdir -p /var/lib/boot-update

    if [ -f "$MARKER_FILE" ]; then
      LAST_BOOT_ID=$(cat "$MARKER_FILE")
      if [ "$CURRENT_BOOT_ID" = "$LAST_BOOT_ID" ]; then
        log_info "Update check already completed for this boot session."
        exit 0
      fi
    fi

    # Mark this boot as checked FIRST to prevent loops
    echo "$CURRENT_BOOT_ID" > "$MARKER_FILE"

    # Now switch to TTY and show output
    if ${pkgs.systemd}/bin/systemctl is-active display-manager.service &>/dev/null; then
      log_info "Stopping display manager for update process..."
      ${pkgs.systemd}/bin/systemctl stop display-manager.service
      STOPPED_DM=true
    else
      STOPPED_DM=false
    fi

    # Clear and switch to TTY1
    ${pkgs.util-linux}/bin/chvt 1 2>/dev/null || true
    ${pkgs.coreutils}/bin/sleep 1

    # Output to both TTY1 and journal
    exec 1> >(${pkgs.coreutils}/bin/tee /dev/tty1 | ${pkgs.systemd}/bin/systemd-cat -t boot-update)
    exec 2>&1

    ${pkgs.ncurses}/bin/clear
    log_header "Boot Update Service - Checking for upstream changes"
    log_info "Please wait while checking for system updates..."
    log_warning "Do not attempt to log in during this process"

    # Wait for network to be available
    log_info "Waiting for network connectivity..."
    for i in {1..30}; do
      if ${pkgs.iputils}/bin/ping -c 1 -W 2 github.com &> /dev/null; then
        log_success "Network is available."
        break
      fi
      if [ $i -eq 30 ]; then
        log_error "Network not available after 30 seconds. Skipping update."
        ${pkgs.coreutils}/bin/sleep 3
        if [ "$STOPPED_DM" = true ]; then
          ${pkgs.systemd}/bin/systemctl start display-manager.service
        fi
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 1
    done

    NEEDS_REBOOT=false
    export HOME="/home/${username}"
    export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i /home/${username}/.ssh/id_ed25519 -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/home/${username}/.ssh/known_hosts"
    PASSPHRASE=$(${pkgs.coreutils}/bin/cat ${sshPassphraseFile})

    # ===== UPDATE SYSTEM FLAKE =====
    log_header "Checking system configuration repository"

    cd "${flakeDir}" || {
      log_error "Failed to change directory to ${flakeDir}"
      ${pkgs.coreutils}/bin/sleep 5
      if [ "$STOPPED_DM" = true ]; then
        ${pkgs.systemd}/bin/systemctl start display-manager.service
      fi
      exit 0
    }

    GIT_CMD="${pkgs.git}/bin/git -c safe.directory=${flakeDir}"

    log_info "Verifying repository is in a clean state..."
    if ! ${pkgs.su}/bin/runuser -u ${username} -- $GIT_CMD diff --quiet HEAD --; then
      log_error "Git repository is dirty. Skipping system update."
    else
      log_success "Repository is clean."

      log_info "Fetching upstream changes..."
      if ! ${pkgs.su}/bin/runuser -u ${username} -p -- \
          ${pkgs.sshpass}/bin/sshpass -p "$PASSPHRASE" -P "passphrase" \
          $GIT_CMD fetch origin; then
        log_error "Failed to fetch from upstream."
      else
        COMMITS_BEHIND=$(${pkgs.su}/bin/runuser -u ${username} -- $GIT_CMD rev-list --count HEAD..origin/main)

        if [ "$COMMITS_BEHIND" -eq 0 ]; then
          log_success "System is up to date with origin/main. No update needed."
        else
          log_info "Upstream changes detected ($COMMITS_BEHIND commits behind). Pulling changes..."
          if ! ${pkgs.su}/bin/runuser -u ${username} -p -- \
              ${pkgs.sshpass}/bin/sshpass -p "$PASSPHRASE" -P "passphrase" \
              $GIT_CMD pull origin main; then
            log_error "Failed to pull changes from upstream."
          else
            NEW_COMMIT=$(${pkgs.su}/bin/runuser -u ${username} -- $GIT_CMD rev-parse HEAD)
            log_success "Successfully pulled changes. New commit: ''${NEW_COMMIT:0:7}"

            log_info "Updating flake inputs..."
            ${pkgs.su}/bin/runuser -u ${username} -- ${pkgs.nix}/bin/nix flake update

            GIT_STATUS=$(${pkgs.su}/bin/runuser -u ${username} -- $GIT_CMD status --porcelain)

            if [ -n "$GIT_STATUS" ]; then
              EXPECTED_STATUS=" M flake.lock"
              if [ "$GIT_STATUS" = "$EXPECTED_STATUS" ]; then
                log_success "Verified: Only flake.lock was modified. Proceeding."

                ${pkgs.su}/bin/runuser -u ${username} -- $GIT_CMD add flake.lock
                log_info "Committing flake.lock..."
                ${pkgs.su}/bin/runuser -u ${username} -p -- \
                  ${pkgs.sshpass}/bin/sshpass -p "$PASSPHRASE" -P "passphrase" \
                  $GIT_CMD commit -m "flake: update inputs"

                log_info "Pushing changes to upstream..."
                ${pkgs.su}/bin/runuser -u ${username} -p -- \
                  ${pkgs.sshpass}/bin/sshpass -p "$PASSPHRASE" -P "passphrase" \
                  $GIT_CMD push origin main

                LATEST_HASH=$(${pkgs.su}/bin/runuser -u ${username} -- $GIT_CMD rev-parse HEAD)
                log_success "Changes committed and pushed: ''${LATEST_HASH:0:7}"
              else
                log_error "SECURITY ABORT: Unexpected changes detected!"
                log_error "The following files were modified: $GIT_STATUS"
                ${pkgs.coreutils}/bin/sleep 5
                if [ "$STOPPED_DM" = true ]; then
                  ${pkgs.systemd}/bin/systemctl start display-manager.service
                fi
                exit 0
              fi
            fi

            log_info "Building new system generation..."
            log_warning "This may take several minutes. Please be patient..."
            /run/current-system/sw/bin/secure-rebuild "$NEW_COMMIT" boot
            log_success "System rebuild complete."
            NEEDS_REBOOT=true
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
      if ! ${pkgs.su}/bin/runuser -u ${username} -- $DOTFILES_CMD diff --quiet HEAD --; then
        log_warning "Dotfiles repository has local changes. Stashing them..."
        ${pkgs.su}/bin/runuser -u ${username} -- $DOTFILES_CMD stash
      fi

      log_info "Fetching dotfiles updates..."
      if ! ${pkgs.su}/bin/runuser -u ${username} -p -- \
          ${pkgs.sshpass}/bin/sshpass -p "$PASSPHRASE" -P "passphrase" \
          $DOTFILES_CMD fetch origin; then
        log_error "Failed to fetch dotfiles from upstream."
      else
        DOTFILES_COMMITS_BEHIND=$(${pkgs.su}/bin/runuser -u ${username} -- $DOTFILES_CMD rev-list --count HEAD..origin/main)

        if [ "$DOTFILES_COMMITS_BEHIND" -eq 0 ]; then
          log_success "Dotfiles are up to date with origin/main."
        else
          log_info "Dotfiles have upstream changes. Resetting to match remote..."
          ${pkgs.su}/bin/runuser -u ${username} -- $DOTFILES_CMD reset --hard origin/main
          DOTFILES_NEW=$(${pkgs.su}/bin/runuser -u ${username} -- $DOTFILES_CMD rev-parse HEAD)
          log_success "Dotfiles updated to: ''${DOTFILES_NEW:0:7}"
        fi
      fi
    else
      log_warning "Dotfiles directory not found at ${dotfilesDir}"
    fi

    # ===== REBOOT IF NEEDED =====
    if [ "$NEEDS_REBOOT" = true ]; then
      log_header "System updated successfully. Rebooting in 10 seconds..."
      log_warning "Press Ctrl+C to cancel reboot"
      for i in {10..1}; do
        echo -ne "\rRebooting in $i seconds... "
        ${pkgs.coreutils}/bin/sleep 1
      done
      echo
      ${pkgs.systemd}/bin/systemctl reboot
    else
      log_success "All checks complete. No updates needed."
      log_info "Starting display manager in 3 seconds..."
      ${pkgs.coreutils}/bin/sleep 3
      if [ "$STOPPED_DM" = true ]; then
        ${pkgs.systemd}/bin/systemctl start display-manager.service
      fi
    fi

    exit 0
  '';
in {
  programs.nh.enable = true;
  programs.git.enable = true;

  systemd.services."boot-update" = {
    description = "Check for upstream changes and update system on boot";

    # Only run after network, before display manager
    after = ["network-online.target" "multi-user.target"];
    wants = ["network-online.target"];
    before = ["display-manager.service"];

    wantedBy = ["multi-user.target"];

    # Critical: prevent running on system changes
    restartIfChanged = false;
    reloadIfChanged = false;
    stopIfChanged = false;

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;

      User = "root";
      Group = "root";

      # Don't use the systemd TTY features - handle it in script
      StandardOutput = "journal";
      StandardError = "journal";

      ExecStart = "${bootUpdateWorker}";

      TimeoutStartSec = "1800";

      # Prevent systemd from interfering
      KillMode = "process";
    };

    unitConfig = {
      # Additional safety: don't run in containers
      ConditionVirtualization = "!container";
    };
  };

  # Create state directory
  systemd.tmpfiles.rules = [
    "d /var/lib/boot-update 0755 root root -"
  ];

  # Optional: Manual trigger for testing
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "test-boot-update" ''
      #!/usr/bin/env bash
      set -e
      echo "Removing boot marker to simulate fresh boot..."
      sudo rm -f /var/lib/boot-update/last-boot-id
      echo "Running boot update service..."
      sudo systemctl start boot-update.service
      echo "Done. Check: journalctl -u boot-update.service -f"
    '')

    (pkgs.writeShellScriptBin "view-boot-update-log" ''
      #!/usr/bin/env bash
      journalctl -u boot-update.service -b 0
    '')
  ];

  security.sudo-rs.extraRules = [
    {
      users = [username];
      commands = [
        {
          command = "${pkgs.coreutils}/bin/rm";
          options = ["NOPASSWD"];
        }
        {
          command = "${pkgs.systemd}/bin/systemctl";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];
}
