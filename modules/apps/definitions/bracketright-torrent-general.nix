{
  config,
  username,
  ...
}: let
  dotfilesRoot = "/home/${username}/.dotfiles";
in {
  rawAppDefinitions.torrent-general = {
    type = "flatpak";
    id = "org.qbittorrent.qBittorrent";
    key = "bracketright"; # Based on the filename "bracketright-"
    launchCommand = "exec launch-vpn-app flatpak run org.qbittorrent.qBittorrent";
autostart = true;
        };
  home-manager.users.${username}.home.file = {
    "/home/${username}/.var/app/org.qbittorrent.qBittorrent/config/qBittorrent" = {
      source = config.home-manager.users.${username}.lib.file.mkOutOfStoreSymlink "${dotfilesRoot}/var/app/org.qbittorrent.qBittorrent/config/qBittorrent";
      recursive = true;
    };
  };
}
