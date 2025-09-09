{pkgs, ...}: {
  # --- Cursor Theme Configuration ---
  home.pointerCursor = {
    package = pkgs.catppuccin-cursors.latteLight;
    name = "Catppuccin-Latte-Light";
    size = 24;
    gtk.enable = true;
  };

  # --- Disable the default Sway bar ---
  # This explicitly tells Sway to configure no bars.
  wayland.windowManager.sway.config.bars = [];
}
