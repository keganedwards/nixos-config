# File: ./hm-environment.nix
{
  # --- Enable Sway and GTK integration ---
  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
  };

  # --- Set session variables for the graphical environment ---
  home.sessionVariables = {
    XDG_CURRENT_DESKTOP = "sway";
  };
}
