# /opt/nixos-config/modules/nixos/sway/default.nix
# This is a MIXED module. It configures both NixOS and Home Manager.
{
  config,
  pkgs,
  username,
  ...
}: {
  # --- Part 1: System-Level Configuration (for NixOS) ---
  # This part tells NixOS to enable the Home Manager integration for Sway.
  programs.sway = {
    enable = true;
    # As requested, this is set to an empty list.
    extraPackages = [];
  };

  # --- Part 2: User-Level Configuration (for Home Manager) ---
  # This block attempts to inject the HM configuration without receiving any arguments.
  home-manager.users.${username} = {
    imports = [
      ./hm-base.nix
      ./hm-startup.nix
      ./hm-workspaces.nix
    ];
  };
}
