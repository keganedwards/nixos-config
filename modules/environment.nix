{
  pkgs,
  lib,
  ...
}: {
  # This module contributes these packages to the system-wide environment.systemPackages
  environment.systemPackages = lib.unique (with pkgs; [
    python3
    tokei
    dust
    dua
    tree
    playerctl
    gnupg
    wl-clipboard
    libnotify
    wget
    gettext
  ]);
}
