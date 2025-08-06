# File: modules/home-manager/packages-static.nix
# Purpose: Defines a static list of packages to be installed in the user's profile.
# Imported by the main modules/home-manager/default.nix
{
  pkgs, # Package set provided by Home Manager
  lib, # Lib functions provided by Home Manager
  ... # Other arguments are ignored
}: {
  # This module contributes these packages to the global home.packages
  home.packages = lib.unique (with pkgs; [
    # Shell & Core Utils
    tokei
    dust
    dua
    git
    coreutils
    findutils
    gnugrep
    gawk
    gnused
    fzf
    jq
    ripgrep
    tree
    detect-secrets
    gibberish-detector
    sops
    stow
    age
    alejandra
    pre-commit
    # System & Hardware Interaction
    playerctl
    distrobox
    gnupg
    bluetuith
    # Networking
    vopono
    openvpn
    # GUI & Desktop Environment Support / Dependencies
    imagemagick
    ueberzugpp
    wl-clipboard
    libnotify
    gettext
    unzip
    trash-cli
    xdg-utils # Required for desktop integration and update-desktop-database
  ]);
}
