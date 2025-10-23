# /modules/apps/definitions/t-terminal/terminal-app.nix
{terminalConstants, ...}: {
  environment.systemPackages =
    [
      terminalConstants.terminalLauncher
    ]
    ++ terminalConstants.supportPackages;

  rawAppDefinitions."t-terminal" = {
    type = "externally-managed";
    key = "t";
    appId = terminalConstants.appIds.terminal;

    launchCommand = "${terminalConstants.terminalLauncher}/bin/terminal-launcher --terminal --desktop t";

    desktopFile = {
      generate = true;
      displayName = "Terminal";
      iconName = "utilities-terminal";
      categories = ["System" "TerminalEmulator"];
    };
  };
}
