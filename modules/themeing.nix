# /modules/system/themeing.nix
{
  username,
  catppuccin,
  ...
}: let
  catflavor = "latte";
in {
  # --- 1. System-Level Configuration ---

  # Add the Catppuccin binary cache to your system's configuration.
  # This tells Nix to check their server for pre-built packages (like the
  # cursors) before attempting to build them from source.
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    "catppuccin.cachix.org-1:aU+z5bt2nCC0L340o4aFeD720i220Bcy49f7hHMp59A="
  ];
  nix.settings.substituters = [
    "https://cache.nixos.org/"
    "https://catppuccin.cachix.org"
  ];

  # System-wide Catppuccin theming (for GTK apps, etc.)
  catppuccin.enable = true;
  catppuccin.flavor = catflavor;


  # --- 2. User-Level Configuration (Home Manager) ---
  home-manager.users.${username} = {
    imports = [
      # Import the Catppuccin Home Manager module to define user-level options.
      catppuccin.homeModules.catppuccin
    ];

    # Set the Catppuccin options for your user.
    catppuccin = {
      enable = true;
      flavor = catflavor;
      wlogout.enable = false;
      # This will now be downloaded from the Cachix, not built from source.
      cursors = {
        enable = true;
        accent = "light";
      };
    };
  };
}
