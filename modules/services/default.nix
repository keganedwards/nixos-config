# default.nix
{...}: {
  imports = [
    ./flatpak.nix
    ./keyd.nix
    ./night-light.nix
    ./notification-daemon.nix
    ./pipewire.nix
    ./resolved.nix
    ./services.nix
  ];
}
