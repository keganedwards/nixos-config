{config, ...}: let
  dotfilesRoot = "${config.home.homeDirectory}/.dotfiles";
in {
  type = "flatpak";
  id = "org.qbittorrent.qBittorrent";
  key = "bracketright"; # Based on the filename "bracketright-"
  launchCommand = "exec launch-vpn-app flatpak run org.qbittorrent.qBittorrent";
  autostartPriority = 10;
  home.file = {
    "${config.home.homeDirectory}/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfilesRoot}/var/app/org.qbittorrent.qBittorrent/config/qBittorrent";
      recursive = true;
    };
  };
}
