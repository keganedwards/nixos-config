{
  pkgs,
  username,
  ...
}: {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "show-time" ''
      ${pkgs.libnotify}/bin/notify-send -t 2000 "$(date "+%H:%M")"
    '')
  ];

  home-manager.users.${username}.wayland.windowManager.sway.config.keybindings."mod4+Shift+t" = "exec show-time";
}
