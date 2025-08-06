{
  config,
  pkgs,
  lib,
  hostContext,
  ...
}: let
  # Script to check KDE Connect device status and notify on disconnect/connect
  monitorScript = pkgs.writeShellApplication {
    name = "kdeconnect-monitor-check";
    runtimeInputs = with pkgs; [
      coreutils # for touch, cat, sort, tr
      gnugrep # for grep
      gnused # for sed
      # procps # not used
      pkgs.kdePackages.kdeconnect-kde # Provides kdeconnect-cli
      libnotify # for notify-send
      runtimeShell # The shell itself
    ];
    text = ''
      #!${pkgs.runtimeShell}
      set -euo pipefail

      # --- State File ---
      STATE_FILE="/tmp/kdeconnect_monitor_state_''${USER}"
      touch "$STATE_FILE" # Ensure it exists

      # --- Environment Variable Check ---
      if [ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" ] || [ -z "''${DISPLAY:-}" ]; then
        echo "KDE Connect Monitor: Warning - DBUS_SESSION_BUS_ADDRESS or DISPLAY not found. Notifications may fail." >&2
        # Exit early if no D-Bus address, kdeconnect-cli might fail too
        if [ -z "''${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
            echo "KDE Connect Monitor: Error - DBUS_SESSION_BUS_ADDRESS is missing, cannot proceed." >&2
            exit 1
        fi
      fi

      # --- Device Check ---
      # Get IDs of currently reachable devices using kdeconnect-cli
      # Use a temporary variable to capture output and check status
      kdeconnect_output=""
      kdeconnect_status=0
      # Capture stdout, ignore stderr for now, check exit status
      kdeconnect_output=$(kdeconnect-cli --list-devices --list-available 2>/dev/null) || kdeconnect_status=$?

      CURRENTLY_REACHABLE_IDS=""
      if [ $kdeconnect_status -eq 0 ] && [ -n "$kdeconnect_output" ]; then
          # Process successful, non-empty output
          # FIX: Added '_' to the regex character class
          CURRENTLY_REACHABLE_IDS=$(echo "$kdeconnect_output" | grep -- 'reachable' | sed -E 's/.*: ([0-9a-zA-Z_]+) .*/\1/' | sort)
      else
          # Handle command failure or empty output
          echo "KDE Connect Monitor: Warning - 'kdeconnect-cli --list-devices --list-available' failed (status $kdeconnect_status) or returned no reachable devices." >&2
          # Assume no devices are reachable in case of failure
          CURRENTLY_REACHABLE_IDS=""
      fi

      # Read IDs from the last check
      PREVIOUSLY_REACHABLE_IDS=$(cat "$STATE_FILE")

      # --- Detect Disconnections ---
      while IFS= read -r device_id; do
        [ -z "$device_id" ] && continue # Skip empty lines
        # FIX: Added -- before $device_id
        if ! echo "$CURRENTLY_REACHABLE_IDS" | grep -q -w -F -- "$device_id"; then
          # Get the device name (best effort)
          # FIX: Added -- before $device_id
          # FIX: Refined sed pattern to capture name without leading '- '
          device_name=$(kdeconnect-cli --list-devices 2>/dev/null | grep -- "$device_id" | sed -E 's/^- *([^:]+): .*/\1/' || echo "$device_id (name lookup failed)")
          # Handle case where sed might fail even if grep succeeds
          if [ -z "$device_name" ] || [[ "$device_name" == *"(name lookup failed)"* ]]; then
              device_name="$device_id (name lookup failed)"
          fi

          echo "KDE Connect Monitor: Device disconnected - $device_name ($device_id)" >&2
          notify-send --expire-time=10000 "KDE Connect" "Device disconnected: $device_name" || echo "KDE Connect Monitor: notify-send failed for disconnect" >&2
        fi
      done <<< "$PREVIOUSLY_REACHABLE_IDS"

      # --- Detect Connections ---
      while IFS= read -r device_id; do
         [ -z "$device_id" ] && continue # Skip empty lines
         # FIX: Added -- before $device_id
         if ! echo "$PREVIOUSLY_REACHABLE_IDS" | grep -q -w -F -- "$device_id"; then
           # Get the device name (best effort)
           # FIX: Added -- before $device_id
           # FIX: Refined sed pattern to capture name without leading '- '
           device_name=$(kdeconnect-cli --list-devices 2>/dev/null | grep -- "$device_id" | sed -E 's/^- *([^:]+): .*/\1/' || echo "$device_id (name lookup failed)")
           # Handle case where sed might fail even if grep succeeds
           if [ -z "$device_name" ] || [[ "$device_name" == *"(name lookup failed)"* ]]; then
               device_name="$device_id (name lookup failed)"
           fi

           echo "KDE Connect Monitor: Device connected - $device_name ($device_id)" >&2
           # Optional: Uncomment to notify on connect
           # notify-send --expire-time=5000 "KDE Connect" "Device connected: $device_name" || echo "KDE Connect Monitor: notify-send failed for connect" >&2
         fi
      done <<< "$CURRENTLY_REACHABLE_IDS"

      # --- Update State ---
      echo "$CURRENTLY_REACHABLE_IDS" > "$STATE_FILE"
      echo "KDE Connect Monitor: Check complete." >&2

    ''; # End of script text
  }; # End of writeShellApplication
in {
  # Define the systemd service unit
  systemd.user.services.kdeconnect-monitor = {
    Unit = {
      Description = "Monitor KDE Connect device connections/disconnections";
      After = ["graphical-session-pre.target" "plasma-plasmashell.service" "graphical-session.target" "kdeconnectd.service"];
      PartOf = ["graphical-session.target" "kdeconnectd.service"];
    };
    Service = {
      Type = "oneshot";
      # Import necessary environment variables from the user session manager
      # Note: This import might sometimes race with variable availability.
      # Consider alternative methods if consistently failing (e.g., wrapper script sourcing env).
      ExecStartPre = "${pkgs.systemd}/bin/systemctl --user --no-block import-environment DISPLAY DBUS_SESSION_BUS_ADDRESS";
      ExecStart = "${monitorScript}/bin/kdeconnect-monitor-check";
      # Log output to journal for debugging
      StandardOutput = "journal";
      StandardError = "journal";
    };
    # No Install section needed, timer manages activation
  };

  # Define the systemd timer unit
  systemd.user.timers.kdeconnect-monitor = {
    Unit = {
      Description = "Periodically check KDE Connect device status";
    };
    Timer = {
      # Run 1 minute after boot/login, then every 60 seconds
      OnBootSec = "1m"; # Reduced initial delay slightly
      OnUnitActiveSec = "60s";
      AccuracySec = "5s";
      RandomizedDelaySec = "10s";
      Unit = "kdeconnect-monitor.service";
    };
    Install = {
      WantedBy = ["timers.target"];
    };
  };
}
