{
  lib,
  pkgs,
  username,
  windowManagerConstants,  
  terminalConstants,
  ...
}: let
  clipseExe = lib.getExe pkgs.clipse;
  clipseAppId = "clipse-terminal";
  
  launchClipseCommand = 
    if terminalConstants.supportsCustomAppId
    then "${terminalConstants.launchWithAppId clipseAppId} ${clipseExe}"
    else "${terminalConstants.defaultLaunchCmd} ${clipseExe}";
    
  startClipseListener = "${clipseExe} --listen";
in windowManagerConstants.withConfig {} {
  packages = [pkgs.clipse];
  
  keybindings = {
    "Mod+Shift+C" = launchClipseCommand;
  };
  
  startup = [
    startClipseListener
  ];
  
  windowRules = [
    (windowManagerConstants.window.fullscreenRule clipseAppId)
  ];
}
