{
  pkgs,
  lib,
windowManagerConstants,
...
}:
lib.mkMerge [
  {
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "battery-status" ''
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
    ];
  }

  (windowManagerConstants.setKeybinding "Mod+Shift+b" "exec battery-status")
]
