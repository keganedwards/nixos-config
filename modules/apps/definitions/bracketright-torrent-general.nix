# modules/home-manager/apps/definitions/bracketright-torrent-general.nix
{config, ...}: let
  # Define the absolute path to your dotfiles directory.
  dotfilesRoot = "${config.home.homeDirectory}/.dotfiles";
in {
  # Part 1: Define the application itself using your framework.
  # This makes it available to your system, but we will NOT manage its config here.
  type = "flatpak";
  id = "org.qbittorrent.qBittorrent";
  key = "bracketright"; # Based on the filename "bracketright-"
  vpn = {
    enabled = true;
  };
  # Part 2: Explicitly define the symlink using the direct, correct method.
  # This gives your dotfiles exclusive control over the configuration.
  home.file = {
    # The key is the full, absolute path to the target symlink.
    # This is the directory where the Flatpak stores its configuration.
    "${config.home.homeDirectory}/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent" = {
      # The source is a DIRECT, OUT-OF-STORE link to your live dotfiles.
      # This forces Home Manager to create the symlink you want and forbids
      # it from copying anything to the /nix/store.
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesRoot}/var/app/org.qbittorrent.qBittorrent/config/qBittorrent";

      # It's good practice to ensure the parent directories exist.
      recursive = true;
    };
  };
}
