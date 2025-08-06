# /etc/nixos/modules/home-manager/systemd/dotfiles-sync.nix
{
  pkgs,
  config,
  ...
}: let
  dotfilesRepoDir = "${config.home.homeDirectory}/.dotfiles";
  swayReloadScript = "${config.home.homeDirectory}/.config/scripts/sway/reload-sway-env.sh";
  gitRemoteName = "origin";
  gitBranchName = "main";
  runOnLoginDelay = "2min";

  updateScript = pkgs.writeShellScriptBin "dotfiles-sync" ''
    #!${pkgs.bash}/bin/bash

    handle_exit() {
      local exit_code="$1"
      if [ "$exit_code" -ne 0 ]; then
        local message="Dotfiles Sync Script FAILED (Exit Code: $exit_code)"
        echo "$message"
        if [ -n "$DBUS_SESSION_BUS_ADDRESS" ]; then
          ${pkgs.libnotify}/bin/notify-send -u critical -a "Dotfiles Sync" "$message"
        else
          echo "WARNING: DBUS_SESSION_BUS_ADDRESS not set. Cannot send desktop notification for failure."
        fi
      fi
    }

    trap 'handle_exit $?' EXIT
    set -euo pipefail

    echo "Dotfiles Sync script started (runs once after login)."
    cd "${dotfilesRepoDir}" || { echo "ERROR: Could not cd to ${dotfilesRepoDir}"; exit 1; }

    echo "Fetching updates from ${gitRemoteName}/${gitBranchName} for ${dotfilesRepoDir}..."
    PATH=${pkgs.git}/bin:${pkgs.openssh}/bin:${pkgs.libnotify}/bin:$PATH

    if ! git fetch "${gitRemoteName}"; then
      echo "ERROR: 'git fetch' failed."
      exit 1
    fi

    LOCAL_SHA=$(git rev-parse HEAD)
    REMOTE_SHA=$(git rev-parse "${gitRemoteName}/${gitBranchName}")

    if [ "$LOCAL_SHA" = "$REMOTE_SHA" ]; then
      echo "Dotfiles (${dotfilesRepoDir}) are already up-to-date."
    else
      echo "Changes detected. Resetting ${dotfilesRepoDir} to ${gitRemoteName}/${gitBranchName} and cleaning..."
      if ! git reset --hard "${gitRemoteName}/${gitBranchName}"; then
        echo "ERROR: 'git reset --hard' failed."
        exit 1
      fi
      if ! git clean -fdx; then
        echo "ERROR: 'git clean -fdx' failed."
        exit 1
      fi
      echo "Dotfiles (${dotfilesRepoDir}) updated successfully."

      if [ -f "${swayReloadScript}" ] && [ -x "${swayReloadScript}" ]; then
        echo "Executing Sway reload script: ${swayReloadScript}"
        if ! ${pkgs.bash}/bin/bash "${swayReloadScript}"; then
          echo "ERROR: Sway reload script failed."
          exit 1
        fi
        echo "Sway reload script finished."
      elif [ -f "${swayReloadScript}" ]; then
        echo "WARNING: Sway reload script found but is not executable: ${swayReloadScript}"
      else
        echo "WARNING: Sway reload script not found: ${swayReloadScript}"
      fi
    fi
    echo "Dotfiles Sync script finished successfully."
    exit 0
  '';
in {
  systemd.user.services.dotfiles-sync = {
    Unit = {
      Description = "Sync ~/.dotfiles git repository and reload environment (once after login)";
      Documentation = ["man:systemd.service(5)"];
      After = ["network-online.target" "graphical-session.target"];
      Wants = ["network-online.target" "graphical-session.target"];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${updateScript}/bin/dotfiles-sync";
    };
  };

  systemd.user.timers.dotfiles-sync = {
    Unit = {
      Description = "Timer to sync ~/.dotfiles git repository once after login";
      Documentation = ["man:systemd.timer(5)"];
    };
    Timer = {
      OnStartupSec = runOnLoginDelay;
      Unit = "dotfiles-sync.service";
    };
    Install.WantedBy = ["timers.target"];
  };

  home.packages = [pkgs.libnotify];
}
