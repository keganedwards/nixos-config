# modules/sway/lock-screen.nix
{pkgs, ...}: let
  swayLockSecure = pkgs.writeShellScriptBin "sway-lock-secure" ''
    #!${pkgs.bash}/bin/bash
    (
      set -euo pipefail
      COREUTILS_BIN=${pkgs.coreutils}/bin
      WALLPAPER="$HOME/.local/share/wallpapers/Bing/lockscreen.jpg"

      calculate_delay() {
        local attempts=$1
        (( attempts >= 141 )) && $COREUTILS_BIN/echo $((24*3600)) && return
        (( attempts >= 31 )) && $COREUTILS_BIN/echo $((30*(2**((attempts-30)/10)))) && return
        case $attempts in
          6|1[1-9]|2[0-9]|30) $COREUTILS_BIN/echo 30 ;;
          *) $COREUTILS_BIN/echo 0 ;;
        esac
      }

      while true; do
        TEMP_LOG=$($COREUTILS_BIN/mktemp)
        FAILURE_COUNT_FILE=$($COREUTILS_BIN/mktemp)
        $COREUTILS_BIN/echo 0 > "$FAILURE_COUNT_FILE"

        cleanup() {
          if [[ -n "''${MONITOR_PID-}" ]]; then kill "$MONITOR_PID" 2>/dev/null || true; fi
          if [[ -n "''${SWAYLOCK_PID-}" ]]; then kill "$SWAYLOCK_PID" 2>/dev/null || true; fi
          $COREUTILS_BIN/rm -f "$TEMP_LOG" "$FAILURE_COUNT_FILE"
        }
        trap cleanup EXIT

        if [[ -f "$WALLPAPER" ]]; then
          ${pkgs.swaylock}/bin/swaylock --image "$WALLPAPER" --font "Fira Code" --show-failed-attempts 2> "$TEMP_LOG" &
        else
          ${pkgs.swaylock}/bin/swaylock --color 000000 --show-failed-attempts 2> "$TEMP_LOG" &
        fi
        SWAYLOCK_PID=$!

        (
          $COREUTILS_BIN/tail -f "$TEMP_LOG" | while read -r line; do
            if [[ "$line" == *"pam_authenticate failed"* ]]; then
              current=$($COREUTILS_BIN/cat "$FAILURE_COUNT_FILE")
              current=$((current + 1))
              $COREUTILS_BIN/echo "$current" > "$FAILURE_COUNT_FILE"
              DELAY=$(calculate_delay "$current")
              if [[ "$DELAY" -gt 0 ]]; then
                kill "$SWAYLOCK_PID" 2>/dev/null || true
                exit 0
              fi
            fi
          done
        ) &
        MONITOR_PID=$!

        wait "$SWAYLOCK_PID" || true
        SWAYLOCK_EXIT_CODE=$?

        kill "$MONITOR_PID" 2>/dev/null || true
        failure_count=$($COREUTILS_BIN/cat "$FAILURE_COUNT_FILE")
        trap - EXIT
        $COREUTILS_BIN/rm -f "$TEMP_LOG" "$FAILURE_COUNT_FILE"

        if [[ "$SWAYLOCK_EXIT_CODE" -eq 0 ]]; then
          break
        else
          DELAY=$(calculate_delay "$failure_count")
          if [[ "$DELAY" -gt 0 ]]; then
            $COREUTILS_BIN/sleep "$DELAY"
          fi
        fi
      done
    ) &
  '';

  # SCRIPT 2: Your original BLOCKING script.
  # Used by the 'before-sleep' event to guarantee a lock before suspend.
  swayLockBlocking = pkgs.writeShellScriptBin "sway-lock-blocking" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail
    COREUTILS_BIN=${pkgs.coreutils}/bin
    WALLPAPER="$HOME/.local/share/wallpapers/Bing/lockscreen.jpg"

    calculate_delay() {
      local attempts=$1
      (( attempts >= 141 )) && $COREUTILS_BIN/echo $((24*3600)) && return
      (( attempts >= 31 )) && $COREUTILS_BIN/echo $((30*(2**((attempts-30)/10)))) && return
      case $attempts in
        6|1[1-9]|2[0-9]|30) $COREUTILS_BIN/echo 30 ;;
        *) $COREUTILS_BIN/echo 0 ;;
      esac
    }

    while true; do
      TEMP_LOG=$($COREUTILS_BIN/mktemp)
      FAILURE_COUNT_FILE=$($COREUTILS_BIN/mktemp)
      $COREUTILS_BIN/echo 0 > "$FAILURE_COUNT_FILE"

      cleanup() {
        if [[ -n "''${MONITOR_PID-}" ]]; then kill "$MONITOR_PID" 2>/dev/null || true; fi
        if [[ -n "''${SWAYLOCK_PID-}" ]]; then kill "$SWAYLOCK_PID" 2>/dev/null || true; fi
        $COREUTILS_BIN/rm -f "$TEMP_LOG" "$FAILURE_COUNT_FILE"
      }
      trap cleanup EXIT

      if [[ -f "$WALLPAPER" ]]; then
        ${pkgs.swaylock}/bin/swaylock --image "$WALLPAPER" --font "Fira Code" --show-failed-attempts 2> "$TEMP_LOG" &
      else
        ${pkgs.swaylock}/bin/swaylock --color 000000 --show-failed-attempts 2> "$TEMP_LOG" &
      fi
      SWAYLOCK_PID=$!

      (
        $COREUTILS_BIN/tail -f "$TEMP_LOG" | while read -r line; do
          if [[ "$line" == *"pam_authenticate failed"* ]]; then
            current=$($COREUTILS_BIN/cat "$FAILURE_COUNT_FILE")
            current=$((current + 1))
            $COREUTILS_BIN/echo "$current" > "$FAILURE_COUNT_FILE"
            DELAY=$(calculate_delay "$current")
            if [[ "$DELAY" -gt 0 ]]; then
              kill "$SWAYLOCK_PID" 2>/dev/null || true
              exit 0
            fi
          fi
        done
      ) &
      MONITOR_PID=$!

      wait "$SWAYLOCK_PID" || true
      SWAYLOCK_EXIT_CODE=$?

      kill "$MONITOR_PID" 2>/dev/null || true
      failure_count=$($COREUTILS_BIN/cat "$FAILURE_COUNT_FILE")
      trap - EXIT
      $COREUTILS_BIN/rm -f "$TEMP_LOG" "$FAILURE_COUNT_FILE"

      if [[ "$SWAYLOCK_EXIT_CODE" -eq 0 ]]; then
        break
      else
        DELAY=$(calculate_delay "$failure_count")
        if [[ "$DELAY" -gt 0 ]]; then
          $COREUTILS_BIN/sleep "$DELAY"
        fi
      fi
    done
  '';
in {
  home.packages = [
    swayLockSecure
    swayLockBlocking
    pkgs.swaylock
    pkgs.swayidle
  ];

  programs.swaylock.enable = true;

  services.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 1200; # After 20 minutes, suspend.
        command = "systemctl suspend";
      }
    ];
    events = [
      {
        event = "before-sleep"; # Before suspending, run this...
        command = "${swayLockBlocking}/bin/sway-lock-blocking";
      }
    ];
  };
}
