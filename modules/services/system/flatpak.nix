# /modules/services/system/flatpak.nix
{
  nix-flatpak,
  username,
  ...
}: {
  services.flatpak.enable = true;

  home-manager.users.${username} = {
    imports = [ nix-flatpak.homeManagerModules.nix-flatpak ];

    services.flatpak = {
      enable = true;
      uninstallUnmanaged = true;
    };
  };
}
