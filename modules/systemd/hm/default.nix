# default.nix
{
  imports = [
    ./bing-wallpaper.nix
    ./clean-on-sway-exit.nix
    ./kde-monitor-check.nix
    ./dotfiles-sync.nix
    ./syncthing-monitor.nix
    ./trash-cleaning.nix
  ];
}
