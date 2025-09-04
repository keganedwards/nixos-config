{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "sway-reload-env" ''
      set -e
      SOCK_PATH="$XDG_RUNTIME_DIR/sway-ipc.$UID.$(${pkgs.procps}/bin/pgrep -x sway).sock"
      export SWAYSOCK="$SOCK_PATH"
      echo "SWAYSOCK set to $SWAYSOCK"

      if [ -n "$TMUX" ]; then
        ${pkgs.tmux}/bin/tmux set-environment -g SWAYSOCK "$SWAYSOCK"
        echo "Also updated tmux environment SWAYSOCK"
      fi

      echo "Reloading Sway configuration..."
      ${pkgs.sway}/bin/swaymsg reload

      echo "Waiting 1 second..."
      sleep 1

      echo "Restarting kanshi service..."
      ${pkgs.systemd}/bin/systemctl --user restart kanshi.service

      echo "Sway environment reload complete."
    '')

    (writeShellScriptBin "sway-battery-status" ''
      batf=$(ls /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -1)

      if [ -z "$batf" ]; then
        ${pkgs.libnotify}/bin/notify-send -t 3000 -i "dialog-information" "System Notification" "No battery found"
        exit 0
      fi

      pct=$(cat "$batf")
      st=$(cat "''${batf%/capacity}/status")

      ac_adapter_online_file=$(ls /sys/class/power_supply/AC*/online 2>/dev/null | head -1)
      if [ -z "$ac_adapter_online_file" ]; then
        ac_adapter_online_file=$(ls /sys/class/power_supply/ADP*/online 2>/dev/null | head -1)
      fi

      is_plugged_in=0
      if [ -n "$ac_adapter_online_file" ] && [ -f "$ac_adapter_online_file" ] && [ "$(cat "$ac_adapter_online_file")" -eq 1 ]; then
        is_plugged_in=1
      fi

      icon=""
      emoji=""
      status_text=""

      if [ "$st" = "Charging" ]; then
        icon="battery-good-charging"
        emoji="🔌"
        status_text="Charging"
      elif [ "$st" = "Full" ]; then
        icon="battery-full-charged"
        emoji="🔋🔌"
        status_text="Full"
      elif [ "$is_plugged_in" -eq 1 ] && ( [ "$st" = "Not charging" ] || [ "$st" = "Unknown" ] ); then
        if [ "$pct" -ge 98 ]; then
          icon="battery-full-charged"
          emoji="🔋🔌"
          status_text="Full"
        else
          icon="battery-good-plugged"
          emoji="🔋🔌"
          status_text="Plugged"
        fi
      elif [ "$st" = "Discharging" ] || [ "$is_plugged_in" -eq 0 ]; then
        if [ "$pct" -lt 20 ]; then
          icon="battery-caution"
          emoji="🪫"
          status_text="Low"
        elif [ "$pct" -gt 95 ] && [ "$is_plugged_in" -eq 0 ]; then
          icon="battery-full"
          emoji="🔋"
        else
          icon="battery-good"
          emoji="🔋"
        fi
      else
        icon="battery-missing"
        emoji="🔋❓"
        status_text="$st"
      fi

      primary_notification_text="$emoji $pct%"
      if [ -n "$status_text" ]; then
        primary_notification_text="$primary_notification_text - $status_text"
      fi

      ${pkgs.libnotify}/bin/notify-send -t 3000 -i "$icon" "$primary_notification_text"
    '')

    (writeShellScriptBin "sway-mic-volume" ''
      #!${pkgs.bash}/bin/bash
      vol_output=$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SOURCE@)
      volume=$(echo "$vol_output" | grep -oP "\d+\.\d+")
      percentage=$(echo "$volume" | ${pkgs.gawk}/bin/awk '{printf "%.0f%%", $1 * 100}')

      if [[ "$vol_output" == *"[MUTED]"* ]]; then
        ${pkgs.libnotify}/bin/notify-send -t 1000 -i "microphone-muted" "Microphone" "MUTED ($percentage)"
      else
        ${pkgs.libnotify}/bin/notify-send -t 1000 -i "microphone" "Microphone" "$percentage"
      fi
    '')

    (writeShellScriptBin "sway-sink-volume" ''
      status=$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SINK@)
      vol=$(echo "$status" | grep -oP "Volume: \K[0-9.]+")
      pct=$(${pkgs.gawk}/bin/awk "BEGIN{print int($vol*100)}")
      if echo "$status" | grep -q MUTED; then
        ${pkgs.libnotify}/bin/notify-send -t 2000 "🔇 Muted"
      else
        emoji="🔊"
        [ "$pct" -lt 70 ] && emoji="🔉"
        [ "$pct" -lt 30 ] && emoji="🔈"
        ${pkgs.libnotify}/bin/notify-send -t 2000 "$emoji $pct%"
      fi
    '')

    (writeShellScriptBin "sway-source-volume" ''
      status=$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SOURCE@)
      vol=$(echo "$status" | grep -oP "Volume: \K[0-9.]+")
      pct=$(${pkgs.gawk}/bin/awk "BEGIN{print int($vol*100)}")
      if echo "$status" | grep -q MUTED; then
        ${pkgs.libnotify}/bin/notify-send -t 2000 "🔇 Mic Muted"
      else
        ${pkgs.libnotify}/bin/notify-send -t 2000 "🎤 $pct%"
      fi
    '')

    (writeShellScriptBin "sway-show-time" ''
      ${pkgs.libnotify}/bin/notify-send -t 2000 "$(date "+%H:%M")"
    '')

    (writeShellScriptBin "sway-wifi-status" ''
      conn=$(${pkgs.networkmanager}/bin/nmcli -t -f active,ssid,signal dev wifi | grep "^yes")
      if [ -n "$conn" ]; then
        ssid=$(echo "$conn" | cut -d: -f2)
        sig=$(echo "$conn" | cut -d: -f3)
        icon="network-wireless-signal-weak"
        [ "$sig" -gt 25 ] && icon="network-wireless-signal-ok"
        [ "$sig" -gt 50 ] && icon="network-wireless-signal-good"
        [ "$sig" -gt 75 ] && icon="network-wireless-signal-excellent"
        ${pkgs.libnotify}/bin/notify-send -t 2000 -i "$icon" "$ssid $sig%"
      else
        ${pkgs.libnotify}/bin/notify-send -t 2000 -i network-wireless-offline "Not connected"
      fi
    '')
  ];
}
