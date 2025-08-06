# modules/home-manager/power-management/notifications.nix
{
  lib,
  pkgs,
  ...
}: let
  failureStatusFile = "$HOME/.local/state/nixos/upgrade-failed";
in {
  # Create a systemd service that runs at login to check for failed upgrades
  systemd.user.services.check-nixos-upgrade-status = {
    Unit = {
      Description = "Check for failed NixOS upgrades and notify";
      After = "graphical-session-pre.target";
      PartOf = "graphical-session.target";
    };

    Service = {
      # --- THIS IS THE FIX ---
      # Provides the PATH for commands like 'cat' and 'rm'.
      path = [pkgs.coreutils pkgs.bash];

      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "check-upgrade-status" ''
        #!${pkgs.bash}/bin/bash
        if [ -f "${failureStatusFile}" ]; then
          FAILURE_MSG=$(cat "${failureStatusFile}")
          ${pkgs.libnotify}/bin/notify-send \
            --urgency=critical \
            --icon=dialog-error \
            "NixOS Upgrade Failed" \
            "$FAILURE_MSG"

          # Clean up the file after notification
          rm -f "${failureStatusFile}"
        fi
      '';
    };

    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };

  # Create directories for state
  home.activation.createUpgradeStatusDir = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if [ ! -d "$HOME/.local/state/nixos" ]; then
      $DRY_RUN_CMD mkdir -p $VERBOSE_ARG "$HOME/.local/state/nixos"
    fi
  '';
}
