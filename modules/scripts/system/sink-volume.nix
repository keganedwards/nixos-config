{
  pkgs,
  username,
  ...
}: {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "sink-volume" ''
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
  ];

  # Window manager keybinding
  home-manager.users.${username}.wayland.windowManager.sway.config.keybindings."mod4+Shift+v" = "exec sink-volume";
}
