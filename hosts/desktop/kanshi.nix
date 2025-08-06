{
  config,
  pkgs,
  ...
}: {
  systemd.user.services.kanshi = {
    Unit = {
      Description = "kanshi daemon";
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.kanshi}/bin/kanshi -c ${config.xdg.configHome}/kanshi/config";
      Environment = [
        "WAYLAND_DISPLAY=wayland-1"
        "DISPLAY=:0"
      ];
    };
    Install = {
      WantedBy = ["default.target"];
    };
  };
}
