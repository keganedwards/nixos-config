{
  services.way-displays = {
    enable = true;
    settings = {
      DISABLED = [
        {
          # regex for internal panel (matches "eDP-1")
          NAME_DESC = "!^eDP-1$";

          IF = [
            # any HDMI connector
            {PLUGGED = ["!^HDMI"];}

            # any DP connector
            {PLUGGED = ["!^DP-"];}

            # USB-C style names
            {PLUGGED = ["!^USB-C"];}
          ];
        }
      ];
    };
  };
}
