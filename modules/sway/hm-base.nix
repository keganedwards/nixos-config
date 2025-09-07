{
  config,
  pkgs,
  ...
}: {
  # --- Cursor Theme Configuration ---
  home.pointerCursor = {
    package = pkgs.vanilla-dmz;
    name = "Vanilla-DMZ";
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

      # --- Wallpaper Configuration ---
      # This is a structured option and belongs here.
      output."*".bg = "${config.home.homeDirectory}/.local/share/wallpapers/Bing/desktop.jpg fill";
    };

    extraConfig = ''
      default_border none
    '';
  };

  # --- Session Variable Configuration ---
  home.sessionVariables = {
    XDG_CURRENT_DESKTOP = "sway";
  };
}
