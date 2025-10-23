{
  username,
  pkgs,
  ...
}: {
  programs.niri = {
    enable = true;
    package = pkgs.niri;
  };

  imports = [
    ./input.nix
    ./keybindings.nix
    ./layout.nix
    ./startup.nix
    ./window-rules.nix
    ./workspaces.nix
  ];

  home-manager.users.${username} = {
    programs.niri.settings = {
      prefer-no-csd = true;
      animations.workspace-switch.enable = false;
    };

    home.sessionVariables = {
      XDG_CURRENT_DESKTOP = "niri";
    };
  };
}
