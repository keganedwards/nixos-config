# modules/home-manager/apps/definitions/l-llm-client.nix
{
  type = "flatpak";
  id = "com.jeffser.Alpaca";
  key = "l";
  flatpakOverride = {
    Context.sockets = ["wayland" "!x11" "!fallback-x11" "pulseaudio"];
    Context.devices = ["dri"];
    Context.filesystems = ["home"];
  };
}
