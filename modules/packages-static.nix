{
  pkgs,
  lib,
  ...
}: {
  # This module contributes these packages to the global home.packages
  home.packages = lib.unique (with pkgs; [
    # Shell & Core Utils
    comma
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
    wl-clipboard
    libnotify
    gettext
    unzip
    trash-cli
    xdg-utils # Required for desktop integration and update-desktop-database
  ]);
}
