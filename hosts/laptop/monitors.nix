{
  services.way-displays = {
    enable = true;
    settings = {
      DISABLED = [
        {
          NAME_DESC = "eDP-1";
          IF = [{PLUGGED = ["HDMI-A-2"];}];
        }
      ];
    };
  };
}
