{nix-flatpak, ...}: {
  services.flatpak.enable = true;
  imports = [nix-flatpak.nixosModules.nix-flatpak];
}
