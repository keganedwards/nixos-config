{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  wm = config.windowManagerConstants;
  terminalConstants = config.terminalConstants;

  clipseExe = lib.getExe pkgs.clipse;
  clipseAppId = "clipse-terminal";
  launchClipseCommand = "${terminalConstants.bin} --app-id=${lib.escapeShellArg clipseAppId} ${clipseExe}";
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
