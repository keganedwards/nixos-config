# This is the main "bridge" module for this host.
# It correctly imports both host-specific system modules and
# host-specific user modules in their proper contexts.

{ username, ... }:

{
  # == 1. HOST-SPECIFIC NIXOS MODULES ==
  # Import all system-level modules specific to this host.
  # This file was the old system/default.nix.
  imports = [ ./system-imports.nix ];

  # == 2. HOST-SPECIFIC HOME MANAGER MODULES ==
  # Apply Home Manager modules specific to this host.
  home-manager.users.${username} = {
    # This file was the old home-manager/default.nix.
    imports = [ ./hm-imports.nix ];
  };
}
