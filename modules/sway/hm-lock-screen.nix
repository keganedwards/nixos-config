# modules/home-manager/power-management/lock-screen.nix
{
  lib,
  pkgs,
  ...
}: let
  # Direct conversion of the working script
  lockScript = pkgs.writeShellScriptBin "sway-lock-fancy" ''
    #!${pkgs.bash}/bin/bash
    WALLPAPER="$HOME/.local/share/wallpapers/Bing/lockscreen.jpg"

    calculate_delay() {
      local attempts=$1
      (( attempts >= 141 )) && echo $((24*3600)) && return
      (( attempts >= 31 )) && echo $((30*(2**((attempts-30)/10)))) && return
      case $attempts in
        6|1[1-9]|2[0-9]|30) echo 30 ;;
        *) echo 0 ;;
      esac
    }

    while true; do
      TEMP_LOG=$(mktemp)
      FAILURE_COUNT_FILE=$(mktemp)
      echo 0 > "$FAILURE_COUNT_FILE"

      if [[ -f "$WALLPAPER" ]]; then
        ${pkgs.swaylock}/bin/swaylock --image "$WALLPAPER" --font "Fira Code" --show-failed-attempts 2> "$TEMP_LOG" &
      else
        ${pkgs.swaylock}/bin/swaylock --color 000000 --show-failed-attempts 2> "$TEMP_LOG" &
      fi
      SWAYLOCK_PID=$!

      (
        tail -f "$TEMP_LOG" | while read -r line; do
          if [[ "$line" == *"pam_authenticate failed"* ]]; then
            current=$(cat "$FAILURE_COUNT_FILE")
            current=$((current + 1))
            echo "$current" > "$FAILURE_COUNT_FILE"
            DELAY=$(calculate_delay "$current")
            if [[ "$DELAY" -gt 0 ]]; then
              kill "$SWAYLOCK_PID"
              exit 0
            fi
          fi
        done
      ) &
      MONITOR_PID=$!

      wait "$SWAYLOCK_PID"
      SWAYLOCK_EXIT_CODE=$?

      kill "$MONITOR_PID" 2>/dev/null || true
      rm -f "$TEMP_LOG"

      failure_count=$(cat "$FAILURE_COUNT_FILE")
      rm -f "$FAILURE_COUNT_FILE"

      if [[ "$SWAYLOCK_EXIT_CODE" -eq 0 ]]; then
        break
      else
        DELAY=$(calculate_delay "$failure_count")
        if [[ "$DELAY" -gt 0 ]]; then
          sleep "$DELAY"
        fi
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
    events = [
      {
        # This is the magic part. It runs your lock script before any sleep/hibernate.
        event = "before-sleep";
        command = "${lockScript}/bin/sway-lock-fancy";
      }
      {
        event = "lock";
        command = "${lockScript}/bin/sway-lock-fancy";
      }
    ];
    timeouts = [
      {
        timeout = 300;
        command = "${lockScript}/bin/sway-lock-fancy";
      }
      {
        timeout = 330;
        command = "${pkgs.sway}/bin/swaymsg 'output * dpms off'";
        resumeCommand = "${pkgs.sway}/bin/swaymsg 'output * dpms on'";
      }
      {
        timeout = 600;
        # swayidle can also trigger suspend directly after a timeout.
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
