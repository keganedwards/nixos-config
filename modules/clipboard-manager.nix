# /modules/clipboard-manager.nix
{
  lib,
  pkgs,
  windowManagerConstants,
  terminalConstants,
  ...
}: let
  clipseExe = lib.getExe pkgs.clipse;
  clipseAppId = "clipse-terminal";

  # Use terminal constants to create the wrapper
  clipseWrapper = terminalConstants.createTerminalWithCommand {
    appId = clipseAppId;
    command = clipseExe;
    autoClose = true;
  };

  launchClipseCommand = "${clipseWrapper}/bin/terminal-${clipseAppId}";
  startClipseListener = "${clipseExe} --listen";
in
  windowManagerConstants.withConfig {} {
    packages = [pkgs.clipse clipseWrapper];

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
