# default.nix
{
  imports = [
    ./kde-monitor-check.nix
    ./syncthing-monitor.nix
    ./trash-cleaning.nix
  ];
}
