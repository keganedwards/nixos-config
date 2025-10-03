{
  lib,
  pkgs,
  config,
  ...
}: let
  gituiPackage = pkgs.lazygit;
  gituiCommand = lib.getExe gituiPackage;

  gituiLauncherScript = import ./t-terminal/universal-multiplexer-launcher-script.nix {
    inherit config;
    inherit pkgs;
    appId = "terminal-gitui";
    commandToRun = gituiCommand;
    appType = "gitui";
  };
in {
  rawAppDefinitions.gitui = {
    type = "nix";
    id = "lazygit";
    key = "n";
    isTerminalApp = true;
    launchCommand = "exec ${gituiLauncherScript}/bin/universal-multiplexer-launcher-terminal-gitui";
    appId = "terminal-gitui";
  };

  programs.lazygit.enable = true;
  environment.systemPackages = [gituiLauncherScript];
}
