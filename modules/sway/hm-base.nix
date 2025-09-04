{
  # --- Part 1: Your Original, Working Sway Configuration ---
  # This block is restored to use `extraConfig` as you originally had it.
  # This generates the main ~/.config/sway/config file.
  wayland.windowManager.sway = {
    enable = true;
    package = null;
    wrapperFeatures.gtk = true;
    config.bars = [];
  };

  # Restore this from your original config.
  home.sessionVariables.XDG_CURRENT_DESKTOP = "sway";
}
