{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  wm = config.windowManagerConstants;
  terminal = config.terminalConstants;

  clipseExe = lib.getExe pkgs.clipse;
  clipseAppId = "clipse-terminal";
  
  launchClipseCommand = 
    if terminal.supportsCustomAppId
    then "${terminal.launchWithAppId clipseAppId} ${clipseExe}"
    else "${terminal.defaultLaunchCmd} ${clipseExe}";
    
  startClipseListener = "${clipseExe} --listen";
in {
  home-manager.users.${username} = lib.mkMerge [
    {
      home.packages = [pkgs.clipse];
    }

    (wm.setKeybindings {
      "mod4+Shift+c" = "exec ${launchClipseCommand}";
    })

    (wm.setExtraConfig ''
      exec ${startClipseListener}
      for_window [app_id="${clipseAppId}"] floating enable, resize set width 100 ppt height 100 ppt, move position center
    '')
  ];
}
