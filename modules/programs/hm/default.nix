# /.dotfiles/nixos/home-manager-modules/programs/default.nix
# This file imports all other program configurations in this directory.
{
  imports = [
    ./git-tui.nix
    ./fancy-git.nix
    ./menu.nix
    ./multiplexer.nix
    ./terminal-tools.nix
  ];
}
