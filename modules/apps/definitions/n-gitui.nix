{
  lib,
  pkgs,
  constants,
  ...
}: let
  # Use lazygit as the git UI
  gituiPackage = pkgs.lazygit;
  gituiCommand = lib.getExe gituiPackage;

  # Create a launcher script using our universal launcher - use correct path
  gituiLauncherScript = import ./t-terminal/universal-tmux-launcher-script.nix {
    inherit pkgs;
    appId = "terminal-gitui";
    sessionName = "gitui";
    inherit (constants) terminalBin;
    commandToRun = gituiCommand;
    appType = "gitui"; # Specify this is a git UI app
  };
in {
  gitui = {
    type = "nix";
    id = "lazygit";
    key = "n"; # 'n' is not used by left pinky and can stand for "navigator"
    isTerminalApp = true;
    launchCommand = "exec ${gituiLauncherScript}/bin/universal-tmux-launcher-terminal-gitui";
    appId = "terminal-gitui";
  };
  programs.lazygit.enable = true;
  environment.systemPackages = [gituiLauncherScript];
}
