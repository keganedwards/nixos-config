# This is the corrected Sway configuration module
{config, ...}: let
  # Define the absolute path to your dotfiles directory.
  dotfilesRoot = "${config.home.homeDirectory}/.dotfiles";
  # Path to your wallpaper, taken from your original config.
  wallpaperPath = "${config.home.homeDirectory}/.local/share/wallpapers/Bing/desktop.jpg";
in {
  # --- Part 1: Your Original, Working Sway Configuration ---
  # This block is restored to use `extraConfig` as you originally had it.
  # This generates the main ~/.config/sway/config file.
  wayland.windowManager.sway = {
    enable = true;
    package = null;
    wrapperFeatures.gtk = true;
    config.bars = [];

    # This is the correct way to include your other files. The `include`
    # directive is part of sway's syntax and works on relative paths.
    extraConfig = ''
      include ./base.conf
      include ./input.conf
      include ./keybindings.conf
      output * bg "${wallpaperPath}" fill
    '';
  };

  # --- Part 2: Explicit Symlinking for the Included Files ---
  # This uses the direct, helper-free pattern to create the files that
  # the `extraConfig` block includes.
  home.file = {
    # --- Config Files ---
    "${config.home.homeDirectory}/.config/sway/base.conf" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesRoot}/config/sway/base.conf";
    };
    "${config.home.homeDirectory}/.config/sway/input.conf" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesRoot}/config/sway/input.conf";
    };
    "${config.home.homeDirectory}/.config/sway/keybindings.conf" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesRoot}/config/sway/keybindings.conf";
    };

    # --- Scripts Directory ---
    "${config.home.homeDirectory}/.config/sway/scripts" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesRoot}/config/sway/scripts";
    };
  };

  # Restore this from your original config.
  home.sessionVariables.XDG_CURRENT_DESKTOP = "sway";
}
