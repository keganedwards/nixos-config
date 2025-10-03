{
  pkgs,
  username,
  config,
  lib,
  ...
}: let
  wm = config.windowManagerConstants;
in {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "show-time" ''
      ${pkgs.libnotify}/bin/notify-send -t 2000 "$(date "+%H:%M")"
    '')
  ];

  home-manager.users.${username} = lib.mkMerge [
    (wm.setKeybinding "mod4+Shift+t" "exec show-time")
  ];
}
