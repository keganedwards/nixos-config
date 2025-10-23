{
  username,
  pkgs,
  ...
}: {
  rawAppDefinitions."file-sync-manager" = {
    type = "pwa";
    key = "backspace";
  };

  home-manager.users.${username} = {
    # ----------------------------------------------------------------
    # Syncthing Service Configuration
    # ----------------------------------------------------------------
    services.syncthing = {
      enable = true;
      settings = {
        devices = {
          laptop = {
            id = "CKBYWSE-DNY4KVQ-U4AC42K-EGB2VPQ-NA33UFT-KRQPUJJ-VW5UQV7-YW7IQAP";
            autoAcceptFolders = true;
          };
          desktop = {
            id = "ZXRO7S4-RHWCI6E-C5R3MEV-5ALX4X2-QY2S4IQ-NZS6XUL-3GEES6U-NZALZQJ";
            autoAcceptFolders = true;
          };
          phone = {
            id = "QZIH32G-DFR6QMY-S2VXAND-CEYTCEE-DRH6KB4-W5TUDCB-H2YW44F-DW73GQT";
            autoAcceptFolders = true;
          };
        };
        folders = {
          notes = {
            path = "/home/${username}/Documents/notes";
            devices = ["laptop" "desktop" "phone"];
          };
          "important-documents" = {
            path = "/home/${username}/Documents/important-documents";
            devices = ["laptop" "desktop" "phone"];
          };
          pictures = {
            path = "/home/${username}/Pictures";
            devices = ["laptop" "desktop" "phone"];
          };
          "new-music" = {
            path = "/home/${username}/Music/new";
            devices = ["laptop" "desktop" "phone"];
          };
          "instrumental-music" = {
            path = "/home/${username}/Music/instrumental";
            devices = ["laptop" "desktop"];
          };
        };
      };
    };

    # ----------------------------------------------------------------
    # Syncthing Monitor Service and Timer
    # ----------------------------------------------------------------
    systemd.user.services.syncthing-monitor = let
      monitorScript = pkgs.writeShellApplication {
        name = "syncthing-monitor-check";
        runtimeInputs = with pkgs; [
          coreutils # for touch, cat, tail, echo
          ripgrep # for rg
          systemd # for journalctl
          libnotify # for notify-send
        ];
        text = ''
          #!${pkgs.runtimeShell}
          set -euo pipefail

          ERROR_KEYWORDS="error|fail|conflict|insufficient space|stopped|panic"
          SINCE_TIME="2 minutes ago"
          LAST_ERROR_FILE="/tmp/syncthing_monitor_last_error_''${USER}"
          touch "$LAST_ERROR_FILE"

          RECENT_ISSUES=$(journalctl --user -u syncthing.service --since "$SINCE_TIME" --no-pager --output=cat | rg -i -E "$ERROR_KEYWORDS" || true)

          if [ -n "$RECENT_ISSUES" ]; then
            LAST_LINE=$(echo "$RECENT_ISSUES" | tail -n 1)
            PREVIOUS_LAST_LINE=$(cat "$LAST_ERROR_FILE")

            if [ "$LAST_LINE" != "$PREVIOUS_LAST_LINE" ]; then
              notify-send -u critical --expire-time=15000 "Syncthing Issue" "Detected: $LAST_LINE"
              echo "$LAST_LINE" > "$LAST_ERROR_FILE"
            fi
          else
            echo "" > "$LAST_ERROR_FILE"
          fi
        '';
      };
    in {
      Unit = {
        Description = "Monitor Syncthing journal for errors";
        After = ["syncthing.service" "graphical-session.target"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "oneshot";
        ExecStartPre = "${pkgs.systemd}/bin/systemctl --user import-environment DISPLAY DBUS_SESSION_BUS_ADDRESS";
        ExecStart = "${monitorScript}/bin/syncthing-monitor-check";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    systemd.user.timers.syncthing-monitor = {
      Unit.Description = "Periodically check Syncthing journal for issues";
      Timer = {
        OnBootSec = "3m";
        OnUnitActiveSec = "90s";
        Unit = "syncthing-monitor.service";
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
