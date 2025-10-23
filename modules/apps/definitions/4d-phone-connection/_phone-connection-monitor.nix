{
  username,
  pkgs,
  ...
}: {
  home-manager.users.${username} = {
    # Define the systemd service unit
    systemd.user.services.kdeconnect-monitor = let
      monitorScript = pkgs.writeShellApplication {
        name = "kdeconnect-monitor-check";
        runtimeInputs = with pkgs; [
          coreutils # for touch, cat, sort, tr
          ripgrep # for rg, replacing grep
          gnused # for sed
          kdePackages.kdeconnect-kde # Provides kdeconnect-cli
          libnotify # for notify-send
        ];
        text = ''
          #!${pkgs.runtimeShell}
          set -euo pipefail

          STATE_FILE="/tmp/kdeconnect_monitor_state_''${USER}"
          touch "$STATE_FILE"

          if [ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
            echo "KDE Connect Monitor: Error - DBUS_SESSION_BUS_ADDRESS is missing, cannot proceed." >&2
            exit 1
          fi

          kdeconnect_output=$(kdeconnect-cli --list-devices --list-available 2>/dev/null) || true
          CURRENTLY_REACHABLE_IDS=""
          if [ -n "$kdeconnect_output" ]; then
            CURRENTLY_REACHABLE_IDS=$(echo "$kdeconnect_output" | rg 'reachable' | sed -E 's/.*: ([0-9a-zA-Z_]+) .*/\1/' | sort)
          fi

          PREVIOUSLY_REACHABLE_IDS=$(cat "$STATE_FILE")

          # --- Detect Disconnections ---
          while IFS= read -r device_id; do
            [ -z "$device_id" ] && continue
            if ! echo "$CURRENTLY_REACHABLE_IDS" | rg -q -w -F -- "$device_id"; then
              device_name=$(kdeconnect-cli --list-devices 2>/dev/null | rg -- "$device_id" | sed -E 's/^- *([^:]+): .*/\1/' || echo "$device_id")
              notify-send --expire-time=10000 "KDE Connect" "Device disconnected: $device_name"
            fi
          done <<< "$PREVIOUSLY_REACHABLE_IDS"

          # --- Detect Connections ---
          while IFS= read -r device_id; do
            [ -z "$device_id" ] && continue
            if ! echo "$PREVIOUSLY_REACHABLE_IDS" | rg -q -w -F -- "$device_id"; then
              device_name=$(kdeconnect-cli --list-devices 2>/dev/null | rg -- "$device_id" | sed -E 's/^- *([^:]+): .*/\1/' || echo "$device_id")
              # notify-send --expire-time=5000 "KDE Connect" "Device connected: $device_name"
            fi
          done <<< "$CURRENTLY_REACHABLE_IDS"

          echo "$CURRENTLY_REACHABLE_IDS" > "$STATE_FILE"
        '';
      };
    in {
      Unit = {
        Description = "Monitor KDE Connect device connections/disconnections";
        After = ["graphical-session.target" "kdeconnectd.service"];
        PartOf = ["graphical-session.target"];
      };
      Service = {
        Type = "oneshot";
        ExecStartPre = "${pkgs.systemd}/bin/systemctl --user --no-block import-environment DISPLAY DBUS_SESSION_BUS_ADDRESS";
        ExecStart = "${monitorScript}/bin/kdeconnect-monitor-check";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    # Define the systemd timer unit
    systemd.user.timers.kdeconnect-monitor = {
      Unit.Description = "Periodically check KDE Connect device status";
      Timer = {
        OnBootSec = "1m";
        OnUnitActiveSec = "60s";
        Unit = "kdeconnect-monitor.service";
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
