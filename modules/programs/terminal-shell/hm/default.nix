{pkgs, ...}: {
  imports = [
    ./aliases.nix
    ./functions
    ./init.nix
  ];

  programs.fish = {
    enable = true;
  };
}
