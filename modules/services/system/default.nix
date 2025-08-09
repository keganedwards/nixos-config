{...}: {
  imports = [
    ./keyd.nix
    ./services.nix
    ./pipewire.nix
    ./resolved.nix
    ./flatpak.nix
  ];
}
