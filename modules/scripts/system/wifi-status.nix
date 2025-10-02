{
  pkgs,
  username,
  ...
}: {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "wifi-status" ''
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

  home-manager.users.${username}.wayland.windowManager.sway.config.keybindings."mod4+Shift+w" = "exec wifi-status";
}
