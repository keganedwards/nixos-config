# File: modules/home-manager/apps/definitions/t-terminal/terminal-app.nix
{
  pkgs,
  constants,
  ...
}: let
  universalLauncher = import ./universal-tmux-launcher-script.nix {
    inherit pkgs;
    appId = "terminal";
    sessionName = "terminal";
    inherit (constants) terminalBin;
    commandToRun = "$SHELL";
    appType = "terminal"; # Specify this is a terminal
  };
in {
  terminal = {
    type = "nix";
    id = constants.terminalName;
    appId = "terminal";
    key = "t";

    # Use the multiplexer launcher
    launchCommand = "exec ${universalLauncher}/bin/universal-tmux-launcher-terminal";

    desktopFile = {
      generate = true;
      displayName = "Terminal (Tabbed)";
      iconName = constants.terminalName;
      categories = ["System" "TerminalEmulator"];
    };
  };
  environment.systemPackages = [
    pkgs.tmux
    pkgs.jq
    pkgs.coreutils
    universalLauncher
  ];
}
