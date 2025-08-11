# /modules/system/upgrade.nix
{
  pkgs,
  username,
  flakeDir,
  ...
}: let
  upgradeAndPowerOffWorker = pkgs.writeShellScript "system-upgrade-worker" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    FINAL_ACTION=$1
    log_header()  { echo -e "\n\e[1;35m--- $1 ---\e[0m"; }
    log_info()    { echo -e "\e[34m[INFO]\e[0m $1"; }
    log_success() { echo -e "\e[32m[SUCCESS]\e[0m $1"; }
    log_error()   { echo -e "\e[1;31m[ERROR]\e[0m $1"; }

    if command -v swaymsg &> /dev/null; then swaymsg exit || true; fi
    if command -v flatpak &> /dev/null; then runuser -u ${username} -- flatpak kill com.brave.Browser || true; fi

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
      runuser -u ${username} -- ${pkgs.gnupg}/bin/gpg-connect-agent updatestartuptty /bye >/dev/null
      log_info "Committing flake.lock...";
      runuser -u ${username} -- env GPG_TTY=$(tty) $GIT_CMD commit -m "flake: update inputs"
      LATEST_HASH=$(runuser -u ${username} -- $GIT_CMD rev-parse HEAD)

      log_info "Verifying signature of new commit: ''${LATEST_HASH:0:7}"
      if ! runuser -u ${username} -- $GIT_CMD verify-commit "$LATEST_HASH"; then
        log_error "FATAL: The commit just created could not be verified. Aborting."; exit 1
      fi
      log_success "Signature verified."

      log_info "Building new system generation and setting it as default for next boot..."
      /run/current-system/sw/bin/secure-rebuild "$LATEST_HASH" boot
      log_success "System build complete."
    else
      log_error "SECURITY ABORT: Unexpected changes detected!";
      log_error "The following files were modified: $GIT_STATUS"; exit 1
    fi

    FLATPAK_PID=""
    if command -v flatpak &> /dev/null; then
      (
        log_header "Updating Flatpaks (in background)"
        runuser -u ${username} -- flatpak update -y || log_info "Flatpak update failed or no updates."
        runuser -u ${username} -- flatpak uninstall --unused -y || log_info "No unused Flatpaks."
        log_success "Flatpak operations complete."
      ) &
      FLATPAK_PID=$!
    fi
    if [ "$FINAL_ACTION" = "shutdown" ]; then
      log_header "Running System Maintenance";
      ${pkgs.nix}/bin/nix-store --optimise;
      ${pkgs.nix}/bin/nix-collect-garbage --delete-older-than 30d;
      log_success "System maintenance complete."
    fi
    if [ -n "$FLATPAK_PID" ]; then
      log_info "Waiting for Flatpak operations to complete..."; wait "$FLATPAK_PID";
    fi

    log_success "All tasks completed successfully!"
    log_header "Proceeding with final action: $FINAL_ACTION"

    if [ "$FINAL_ACTION" = "reboot" ]; then
        ${pkgs.systemd}/bin/systemctl reboot
    elif [ "$FINAL_ACTION" = "shutdown" ]; then
        ${pkgs.systemd}/bin/systemctl poweroff
    fi
  '';
in {
  # This declaratively configures the system-wide git config (/etc/gitconfig).
  # The root user inherits this, trusting your flake repo when nixos-rebuild uses git.
  programs.git = {
    enable = true;
    config = {
      safe.directory = flakeDir;
    };
  };

  security.sudo.extraRules = [
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
        Environment = "PATH=${pkgs.git}/bin:${pkgs.gnupg}/bin:${pkgs.ncurses}/bin:${pkgs.sway}/bin:${pkgs.flatpak}/bin:/run/current-system/sw/bin";
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
        Environment = "PATH=${pkgs.git}/bin:${pkgs.gnupg}/bin:${pkgs.ncurses}/bin:${pkgs.sway}/bin:${pkgs.flatpak}/bin:/run/current-system/sw/bin";
        ExecStart = "${upgradeAndPowerOffWorker} shutdown";
        User = "root";
        Group = "root";
      };
    };
  };

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
