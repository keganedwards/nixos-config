# /modules/default.nix
#
# This is the main "bridge" module for the flat module structure.
# It correctly imports both system-level modules and user-level
# Home Manager modules in their proper contexts.
{username, ...}: {
  # == 1. SYSTEM-LEVEL & MERGED MODULES ==
  # These modules apply to the whole NixOS system. The merged modules
  # (programs, services, etc.) will correctly route their hm- and
  # system-specific parts from within their own default.nix.
  imports = [
    # Original system modules
    ./boot.nix
    ./environment.nix
    ./fonts.nix
    ./hardware.nix
    ./i18n.nix
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
    ./scripts
    ./services
    ./systemd
    ./xdg
  ];

  # == 2. USER-LEVEL ONLY MODULES (Home Manager Configuration) ==
  # These are modules that are purely for Home Manager and did not have
  # a system-level counterpart to be merged with.
  home-manager.users.${username} = {
    imports = [
      ./apps
      ./desktop-entries.nix
      ./directories.nix
      ./packages-static.nix
      ./screenshot-configuration.nix
    ];
  };
}
