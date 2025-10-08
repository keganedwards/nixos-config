{
  pkgs,
  lib,
  windowManagerConstants,
  ...
}:
lib.mkMerge [
  # 1. The system package for the mic-volume script.
  {
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "mic-volume" ''
        vol_output=$(${pkgs.wireplumber}/bin/wpctl get-volume @DEFAULT_AUDIO_SOURCE@)
        volume=$(echo "$vol_output" | grep -oP "\d+\.\d+")
        percentage=$(echo "$volume" | ${pkgs.gawk}/bin/awk '{printf "%.0f%%", $1 * 100}')

        if [[ "$vol_output" == *"[MUTED]"* ]]; then
          ${pkgs.libnotify}/bin/notify-send -t 1000 -i "microphone-muted" "Microphone" "MUTED ($percentage)"
        else
          ${pkgs.libnotify}/bin/notify-send -t 1000 -i "microphone" "Microphone" "$percentage"
        fi
      '')
    ];
  }

  # 2. The window manager keybinding, set using the global helper.
  # This assumes your windowManagerConstants are configured for Sway.
  (windowManagerConstants.setKeybinding "mod+Shift+m" "exec mic-volume")
]
