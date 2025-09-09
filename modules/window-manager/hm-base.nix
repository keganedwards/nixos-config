{
  config,
  pkgs,
  ...
}: {
  # --- Cursor Theme Configuration ---
  home.pointerCursor = {
    # 1. Point to the specific output from the catppuccin-cursors package
    package = pkgs.catppuccin-cursors.latteLight;

    # 2. The 'name' must match the theme's internal name
    name = "Catppuccin-Latte-Light";

    size = 24;
    gtk.enable = true;
    x11.enable = true;
    sway.enable = true;
  };

  # --- Sway Window Manager Configuration ---
  wayland.windowManager.sway = {
    enable = true;
    package = null;
    wrapperFeatures.gtk = true;
    config = {
      bars = [];
      output."*".bg = "${config.home.homeDirectory}/.local/share/wallpapers/Bing/desktop.jpg fill";
    };
    extraConfig = ''
      default_border none
      include ./base.conf
    '';
  };

  # --- Session Variable Configuration ---
  home.sessionVariables = {
    XDG_CURRENT_DESKTOP = "sway";
  };
}
