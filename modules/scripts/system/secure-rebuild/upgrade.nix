{
  pkgs,
  config,
  username,
  flakeDir,
  ...
}: let
  sshPassphraseFile = config.sops.secrets."ssh-key-passphrase".path;

  upgradeAndPowerOffWorker = pkgs.writeShellScript "system-upgrade-worker" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    FINAL_ACTION=$1
    log_header()  { echo -e "\n\e[1;35m--- $1 ---\e[0m"; }
    log_info()    { echo -e "\e[34m[INFO]\e[0m $1"; }
    log_success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
    log_error()   { echo -e "\e[1;31m[ERROR]\e[0m $1"; }

    if command -v swaymsg &> /dev/null; then swaymsg exit || true; fi
    # Original command was slightly different, using a more robust version from the previous attempt.
    if command -v flatpak &> /dev/null; then runuser -l ${username} -c "flatpak kill com.brave.Browser" || true; fi

    clear
    log_header "System Upgrade Service Started"
    cd "${flakeDir}" || { log_error "Failed to change directory to ${flakeDir}"; exit 1; }
    GIT_CMD="${pkgs.git}/bin/git -c safe.directory=${flakeDir}"

    log_info "Verifying repository is in a clean state..."
    if ! runuser -u ${username} -- $GIT_CMD diff --quiet HEAD --; then
      log_error "Git repository is dirty. Aborting."; exit 1;
    fi
    log_success "Repository is clean."

    log_info "Updating flake inputs..."
    runuser -u ${username} -- ${pkgs.nix}/bin/nix flake update

    GIT_STATUS=$(runuser -u ${username} -- $GIT_CMD status --porcelain)
    EXPECTED_STATUS=" M flake.lock"

    if [ -z "$GIT_STATUS" ]; then
      log_info "No changes detected after update. System is already up-to-date."
    elif [ "$GIT_STATUS" = "$EXPECTED_STATUS" ]; then
      log_success "Verified: Only flake.lock was modified. Proceeding."

      runuser -u ${username} -- $GIT_CMD add flake.lock
      PASSPHRASE=$(cat ${sshPassphraseFile})
      export HOME="/home/${username}"
      export GIT_SSH_COMMAND="${pkgs.openssh}/bin/ssh -o BatchMode=yes -o StrictHostKeyChecking=no"
      log_info "Committing flake.lock...";
      runuser -u ${username} -p -- \
        ${pkgs.sshpass}/bin/sshpass -p "$PASSPHRASE" -P "passphrase" \
        $GIT_CMD commit -m "flake: update inputs"
      LATEST_HASH=$(runuser -u ${username} -- $GIT_CMD rev-parse HEAD)
      log_info "New commit created: ''${LATEST_HASH:0:7}"
      log_success "Commit signature will be verified by secure-rebuild."
      log_info "Building new system generation and setting it as default for next boot..."
      /run/current-system/sw/bin/secure-rebuild "$LATEST_HASH" boot
      log_success "System build complete."

      # --- Simplified and Conditional Maintenance Block ---
      if [ "$FINAL_ACTION" = "shutdown" ]; then
        log_header "Running Post-Update Maintenance"

        log_info "Updating Flatpaks..."
        # FIX: Use 'runuser -l' to ensure HOME is set correctly for flatpak
        runuser -l ${username} -c "flatpak update -y" || log_info "Flatpak update failed or had no updates."
        runuser -l ${username} -c "flatpak uninstall --unused -y" || log_info "No unused Flatpaks to remove."

        log_info "Cleaning system and user generations..."
        ${pkgs.nh}/bin/nh clean all --keep 5

        log_info "Optimizing Nix store..."
        ${pkgs.nix}/bin/nix store optimise

        log_success "All maintenance tasks complete."
      fi
      # --- End of Maintenance Block ---

    else
      log_error "SECURITY ABORT: Unexpected changes detected!";
      log_error "The following files were modified: $GIT_STATUS"; exit 1
    fi

    log_success "All tasks concluded."
    log_header "Proceeding with final action: $FINAL_ACTION"

    if [ "$FINAL_ACTION" = "reboot" ]; then
        ${pkgs.systemd}/bin/systemctl reboot
    elif [ "$FINAL_ACTION" = "shutdown" ]; then
        ${pkgs.systemd}/bin/systemctl poweroff
    fi
  '';
in {
  # ... rest of the file is unchanged ...
  # Enable nh for improved NixOS rebuild UX
  programs.nh.enable = true;

  # This declaratively configures the system-wide git config (/etc/gitconfig).
  programs.git = {
    enable = true;
    config = {
      safe.directory = flakeDir;
    };
  };

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
        Environment = "PATH=${pkgs.git}/bin:${pkgs.sshpass}/bin:${pkgs.openssh}/bin:${pkgs.ncurses}/bin:${pkgs.sway}/bin:${pkgs.flatpak}/bin:${pkgs.nix-index}/bin:${pkgs.nix}/bin:/run/current-system/sw/bin";
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
        Environment = "PATH=${pkgs.git}/bin:${pkgs.sshpass}/bin:${pkgs.openssh}/bin:${pkgs.ncurses}/bin:${pkgs.sway}/bin:${pkgs.flatpak}/bin:${pkgs.nix-index}/bin:${pkgs.nix}/bin:/run/current-system/sw/bin";
        ExecStart = "${upgradeAndPowerOffWorker} shutdown";
        User = "root";
        Group = "root";
      };
    };
  };

  # User needs sudo to start the systemd services
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

  # Create convenient aliases for the user
  home-manager.users.${username}.home.packages = [
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
