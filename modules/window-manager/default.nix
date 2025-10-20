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
    ./workspaces.nix
    ./startup.nix
    ./keybindings.nix
  ];

  home-manager.users.${username} = {
    programs.niri.settings.prefer-no-csd = true;
    imports = [
      ./layout.nix
      ./animations.nix
      ./window-rules.nix
      ./environment.nix
      ./input.nix
    ];
  };
}
