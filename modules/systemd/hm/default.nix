# default.nix
{
  imports = [
    ./bing-wallpaper.nix
    ./clean-on-sway-exit.nix
    ./kde-monitor-check.nix
    #    ./dotfiles-sync.nix
    ./notifications.nix
    ./syncthing-monitor.nix
    ./trash-cleaning.nix
  ];
}
