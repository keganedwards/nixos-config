{username, ...}: {
  imports = [
    ./apps
    ./boot.nix
    ./clipboard-manager.nix
    ./fonts.nix
    ./hardware.nix
    ./i18n.nix
    ./login-manager.nix
    ./networking.nix
    ./nix.nix
    ./nixpkgs.nix
    ./protected
    ./power-management.nix
    ./security.nix
    ./sops.nix
    ./standard-user.nix
    ./themeing.nix
    ./time.nix
    ./virtualization.nix
    ./window-manager
    ./programs
    ./screenshot-configuration.nix
    ./scripts
    ./services
    ./systemd
    ./xdg
  ];

  home-manager.users.${username} = {
    imports = [
      ./directories.nix
      ./packages-static.nix
      ./idle-management
    ];
  };
}
