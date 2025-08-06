{
  type = "flatpak";
  id = "org.kde.kolourpaint";
  key = "d";
  flatpakOverride = {
    Context.sockets = ["wayland" "!x11" "!fallback-x11" "pulseaudio"];
    Context.devices = ["dri"];
    Context.filesystems = ["home"];
  };
}
