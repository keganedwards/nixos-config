# modules/home-manager/power-management/lock-screen.nix
{
  lib,
  pkgs,
  ...
}: let
  # Direct conversion of the working script
  lockScript = pkgs.writeShellScriptBin "sway-lock-fancy" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    # explicit coreutils path (absolute store path so the script works
    # even when PATH is minimal in systemd / swayidle environments)
    COREUTILS_BIN=${pkgs.coreutils}/bin

    WALLPAPER="$HOME/.local/share/wallpapers/Bing/lockscreen.jpg"

    calculate_delay() {
      local attempts=$1
      # very large number of failures -> long lockout
      (( attempts >= 141 )) && $COREUTILS_BIN/echo $((24*3600)) && return
      # geometric ramp starting after 30
      (( attempts >= 31 )) && $COREUTILS_BIN/echo $((30*(2**((attempts-30)/10)))) && return
      case $attempts in
        6|1[1-9]|2[0-9]|30) $COREUTILS_BIN/echo 30 ;;
        *) $COREUTILS_BIN/echo 0 ;;
      esac
    }

    while true; do
      # create temporary files using absolute coreutils path
      TEMP_LOG=$($COREUTILS_BIN/mktemp)
      FAILURE_COUNT_FILE=$($COREUTILS_BIN/mktemp)
      $COREUTILS_BIN/echo 0 > "$FAILURE_COUNT_FILE"

      # cleanup function ensures temps and background monitors are removed
      cleanup() {
        # best-effort kill of background processes
        if [[ -n "$MONITOR_PID" ]]; then kill "$MONITOR_PID" 2>/dev/null || true; fi
        if [[ -n "$SWAYLOCK_PID" ]]; then kill "$SWAYLOCK_PID" 2>/dev/null || true; fi
        $COREUTILS_BIN/rm -f "$TEMP_LOG" "$FAILURE_COUNT_FILE"
      }
      trap cleanup EXIT

      # start swaylock (stderr -> TEMP_LOG to monitor failures)
      if [[ -f "$WALLPAPER" ]]; then
        ${pkgs.swaylock}/bin/swaylock --image "$WALLPAPER" --font "Fira Code" --show-failed-attempts 2> "$TEMP_LOG" &
      else
        ${pkgs.swaylock}/bin/swaylock --color 000000 --show-failed-attempts 2> "$TEMP_LOG" &
      fi
      SWAYLOCK_PID=$!

      # monitor the swaylock stderr for PAM failure messages
      (
        $COREUTILS_BIN/tail -f "$TEMP_LOG" | while read -r line; do
          if [[ "$line" == *"pam_authenticate failed"* ]]; then
            current=$($COREUTILS_BIN/cat "$FAILURE_COUNT_FILE")
            current=$((current + 1))
            $COREUTILS_BIN/echo "$current" > "$FAILURE_COUNT_FILE"
            DELAY=$(calculate_delay "$current")
            if [[ "$DELAY" -gt 0 ]]; then
              # force swaylock to exit so we can apply the delay in this script
              kill "$SWAYLOCK_PID" 2>/dev/null || true
              exit 0
            fi
          fi
        done
      ) &
      MONITOR_PID=$!

      # wait for swaylock to exit (successful unlock or killed)
      wait "$SWAYLOCK_PID" || true
      SWAYLOCK_EXIT_CODE=$?

      # stop the monitor and collect failure count
      kill "$MONITOR_PID" 2>/dev/null || true
      failure_count=$($COREUTILS_BIN/cat "$FAILURE_COUNT_FILE")

      # remove trap so cleanup isn't run twice when we rm here (we still want final cleanup on script exit)
      trap - EXIT
      # local cleanup (the trap would also do this on final exit)
      $COREUTILS_BIN/rm -f "$TEMP_LOG" "$FAILURE_COUNT_FILE"

      if [[ "$SWAYLOCK_EXIT_CODE" -eq 0 ]]; then
        # unlocked successfully; exit the outer loop
        break
      else
        # if we were forced to exit due to failures, calculate and sleep the delay
        DELAY=$(calculate_delay "$failure_count")
        if [[ "$DELAY" -gt 0 ]]; then
          $COREUTILS_BIN/sleep "$DELAY"
        fi
        # continue to next loop iteration to re-run swaylock
      fi
    done

    exit 0
  '';
in {
  # We only need to package the main lock script now.
  home.packages = [
    lockScript
    pkgs.swaylock
    pkgs.swayidle
  ];

  programs.swaylock.enable = true;

  services.swayidle = {
    enable = true;

    timeouts = [
      {
        # lock after 10 minutes
        timeout = 600;
        command = "${lockScript}/bin/sway-lock-fancy";
      }
      {
        # dpms shortly after lock (optional)
        timeout = 660;
        command = "${pkgs.sway}/bin/swaymsg 'output * dpms off'";
        resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * dpms on'";
      }
      {
        # suspend later (adjust as you like)
        timeout = 1200;
        command = "systemctl suspend";
      }
    ];
  };
  # --- SIMPLIFIED KEYBINDINGS ---
  # These now call systemctl directly. swayidle will intercept them.
  wayland.windowManager.sway.config.keybindings = lib.mkOptionDefault {
    "mod4+Mod1+l" = "exec ${lockScript}/bin/sway-lock-fancy";
    "mod4+Mod1+s" = "exec systemctl suspend";
    "mod4+Mod1+h" = "exec systemctl hibernate";
  };
}
