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

    # Write to journal and console
    exec 1> >(${pkgs.systemd}/bin/systemd-cat -t boot-update) 2>&1

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
        exit 0
      fi
      sleep 1 # Added a small sleep to avoid busy-looping
    done # <--- FIX: Added the missing 'done' keyword

    NEEDS_SHUTDOWN=false
    export HOME="/home/${username}"
    export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -i /home/${username}/.ssh/id_ed25519 -o StrictHostKeyChecking=yes -o UserKnownHostsFile=/home/${username}/.ssh/known_hosts"
    PASSPHRASE=$(cat ${sshPassphraseFile})

    # ===== UPDATE SYSTEM FLAKE =====
    log_header "Checking system configuration repository"

    cd "${flakeDir}" || { log_error "Failed to change directory to ${flakeDir}"; exit 0; }
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
        # Check if we're behind upstream
        LOCAL_COMMIT=$(runuser -u ${username} -- $GIT_CMD rev-parse HEAD)
        REMOTE_COMMIT=$(runuser -u ${username} -- $GIT_CMD rev-parse origin/main)

        if [ "$LOCAL_COMMIT" = "$REMOTE_COMMIT" ]; then
          log_success "System is up to date. No changes to pull."
        else
          log_info "Upstream changes detected. Pulling changes..."
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
              # Check that only flake.lock was modified
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
        # Check if we're behind upstream
        DOTFILES_LOCAL=$(runuser -u ${username} -- $DOTFILES_CMD rev-parse HEAD)
        DOTFILES_REMOTE=$(runuser -u ${username} -- $DOTFILES_CMD rev-parse origin/main)

        if [ "$DOTFILES_LOCAL" = "$DOTFILES_REMOTE" ]; then
          log_success "Dotfiles are up to date."
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

    # ===== SHUTDOWN IF NEEDED =====
    if [ "$NEEDS_SHUTDOWN" = true ]; then
      log_header "System updated successfully. Shutting down in 10 seconds..."
      log_warning "Press Ctrl+C to cancel shutdown"
      sleep 10
      ${pkgs.systemd}/bin/systemctl poweroff
    else
      log_success "All updates complete. System is up to date."
    fi

    exit 0
  '';

  # Script to cancel the boot update service
  cancelBootUpdate = pkgs.writeShellScriptBin "cancel-boot-update" ''
    #!${pkgs.bash}/bin/bash
    echo "Stopping boot update service..."
    sudo systemctl stop boot-update.service
    echo "Service stopped."
  '';
in {
  programs.nh.enable = true;

  programs.git.enable = true;

  systemd.services."boot-update" = {
    description = "Check for upstream changes and update system on boot";
    # Run after system is fully up
    wantedBy = ["multi-user.target"];
    after = ["multi-user.target" "network-online.target"];
    wants = ["network-online.target"];

    # Don't restart if the service exits
    restartIfChanged = false;
    # Don't run during system reconfigurations
    reloadIfChanged = false;

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
      Environment = "PATH=${pkgs.git}/bin:${pkgs.sshpass}/bin:${pkgs.openssh}/bin:${pkgs.ncurses}/bin:${pkgs.nix}/bin:${pkgs.iputils}/bin:/run/current-system/sw/bin";
      ExecStart = "${bootUpdateWorker}";
      User = "root";
      Group = "root";
      # 30 minute timeout for lengthy rebuilds
      TimeoutStartSec = "1800";
    };

    # Only run once per boot
    unitConfig = {
      ConditionPathExists = "!/run/boot-update-ran";
    };
  };

  # Service to mark that we've run
  systemd.services."boot-update-mark" = {
    description = "Mark that boot update has run";
    requires = ["boot-update.service"];
    after = ["boot-update.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/touch /run/boot-update-ran";
      RemainAfterExit = true;
    };
  };

  # User needs sudo to cancel the boot update
  security.sudo-rs.extraRules = [
    {
      users = [username];
      commands = [
        {
          command = "${pkgs.systemd}/bin/systemctl stop boot-update.service";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];

  environment.systemPackages = [
    cancelBootUpdate
  ];
}
