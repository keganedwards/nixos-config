# default.nix
{
  imports = [
    ./bing-wallpaper.nix
    ./clean-on-sway-exit.nix
    ./kde-monitor-check.nix
    ./syncthing-monitor.nix
    ./trash-cleaning.nix
  ];
}
