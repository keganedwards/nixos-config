# /modules/programs/terminal-shell/hm/default.nix
{
  imports = [
    ./aliases.nix
    ./functions
    ./init.nix
    ./security.nix
  ];

  programs.fish = {
    enable = true;
  };
}
