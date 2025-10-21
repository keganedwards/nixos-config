{pkgs, ...}: let
  terminalLauncher = import ./terminal-launcher.nix {inherit pkgs;};
in {
  environment.systemPackages = [
    terminalLauncher
  ];

  rawAppDefinitions."t-terminal" = {
    key = "t";
    id = "neovide";
    appId = "neovide-terminal";

    launchCommand = "${terminalLauncher}/bin/terminal-launcher --terminal";

    desktopFile = {
      generate = true;
      displayName = "Terminal";
      iconName = "utilities-terminal";
      categories = ["System" "TerminalEmulator"];
    };
  };
}
