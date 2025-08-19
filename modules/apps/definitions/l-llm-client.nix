{
  type = "flatpak";
  id = "com.jeffser.Alpaca";
  key = "l";
  flatpakOverride = {
    Context = {
      sockets = ["wayland" "!x11" "!fallback-x11" "pulseaudio"];
      devices = ["dri"];
      filesystems = ["home"];
    };
  };
}
