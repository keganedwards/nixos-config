{
  pkgs,
  lib,
  ...
}: {
  # This module contributes these packages to the global home.packages
  home.packages = lib.unique (with pkgs; [
    python3
    tokei
    dust
    dua
    jq
    tree
    detect-secrets
    gibberish-detector
    pre-commit
    playerctl
    gnupg
    openvpn
    wl-clipboard
    libnotify
    trash-cli
    wget
    gettext
  ]);
}
