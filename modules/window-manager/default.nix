{username, pkgs, ...}: {
  # Enable niri at system level - the flake will handle the package
  programs.niri = {
                enable = true;
                package = pkgs.niri;
        };

  imports = [
    ./workspaces.nix
    ./startup.nix
  ];

  home-manager.users.${username} = {
    imports = [
./layout.nix
                        ./environment.nix
      ./input.nix
      ./keybindings.nix
    ];
  };
}
