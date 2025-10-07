{
  pkgs,
windowManagerConstants, 
lib,
...
}:

lib.mkMerge [
        {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "show-time" ''
      ${pkgs.libnotify}/bin/notify-send -t 2000 "$(date "+%H:%M")"
    '')
  ];
        }  
(windowManagerConstants.setKeybinding "mod+Shift+t" "exec show-time")
]


