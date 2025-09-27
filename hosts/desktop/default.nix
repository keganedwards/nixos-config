{username, ...}: {
  # == 1. HOST-SPECIFIC NIXOS MODULES ==
  # Import all system-level modules specific to this host.
  # This file was the old system/default.nix.
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./steam.nix
    ./hardware.nix
  ];
  # == 2. HOST-SPECIFIC HOME MANAGER MODULES ==
  # Apply Home Manager modules specific to this host.
  home-manager.users.${username} = {
    # This file was the old home-manager/default.nix.
    imports = [
      ./sway.nix
    ];
  };
}
