# modules/home-manager/apps/definitions/media-player/_config-mpv.nix
{
  config,
  pkgs,
  ...
}: let
  # The absolute path to your dotfiles directory.
  dotfilesRoot = "${config.home.homeDirectory}/.dotfiles";
in {
  # --- Part 1: Your "Last Known Good" Configuration ---
  # This correctly enables mpv, installs your custom package, and generates
  # the base mpv.conf file. This block is correct and remains.
  programs.mpv = {
    enable = true;
    package = pkgs.mpv-unwrapped.wrapper {
      scripts = with pkgs.mpvScripts; [
        mpris
        mpv-playlistmanager
        eisa01.smartskip
        eisa01.smart-copy-paste-2
        mpv-image-viewer.equalizer
        mpv-image-viewer.status-line
        mpv-image-viewer.detect-image
        mpv-image-viewer.freeze-window
        mpv-image-viewer.image-positioning
        mpv-image-viewer.minimap
      ];
      mpv = pkgs.mpv-unwrapped.override {
        waylandSupport = true;
      };
    };
    config = {
      vo = "gpu";
      hwdec = "auto-safe";
      save-position-on-quit = true;
    };
    profiles = {};
  };

  # --- Part 2: The Direct Symlinking Logic ---
  # We add this block to create the live symlinks inside the directory
  # that `programs.mpv` manages. This is the cohabitation strategy that works.
  home.file = {
    # This creates a symlink at ~/.config/mpv/scripts
    "${config.home.homeDirectory}/.config/mpv/scripts" = {
      # It points DIRECTLY to your dotfiles, not the Nix store.
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesRoot}/.config/mpv/scripts";
    };

    # This creates a symlink at ~/.config/mpv/script-opts
    "${config.home.homeDirectory}/.config/mpv/script-opts" = {
      # It also points DIRECTLY to your dotfiles.
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesRoot}/.config/mpv/script-opts";
    };
  };
}
