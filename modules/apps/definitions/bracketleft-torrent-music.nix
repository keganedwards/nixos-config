{
  config.rawAppDefinitions."torrent-music" = {
    type = "flatpak";
    id = "org.nicotine_plus.Nicotine";
    key = "bracketleft";
    launchCommand = "exec launch-vpn-app flatpak run org.nicotine_plus.Nicotine'";
    autostart = true;
  };
}
