{
  username,
  pkgs,
  terminalConstants,
  ...
}: {
  programs.lazygit.enable = true;

  home-manager.users.${username} = {
    programs.lazygit.enable = true;
  };

  rawAppDefinitions."n-lazygit" = {
    key = "n";
    id = "lazygit"; # This is the nix package name
    appId = "${terminalConstants.name}-lazygit"; # This is the window manager ID
    type = "externally-managed"; # Since we're managing the launch ourselves
    launchCommand = "${terminalConstants.terminalLauncher}/bin/terminal-launcher --generic --app-id ${terminalConstants.name}-lazygit --desktop n ${pkgs.lazygit}/bin/lazygit";

    desktopFile = {
      generate = false; # Don't generate a desktop file
    };
  };
}
