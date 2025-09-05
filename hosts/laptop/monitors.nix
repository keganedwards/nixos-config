{
  services.way-displays = {
    enable = true;
    settings = {
      DISABLED = [
        {
          NAME_DESC = "!^eDP-1$";

          # Create a list of explicit port names you use.
          # This works because we proved an exact match succeeds.
          IF = [
            {PLUGGED = ["HDMI-A-2"];}
            # Add other specific ports if you have them
            # { PLUGGED = ["DP-1"]; },
            # { PLUGGED = ["USB-C-1"]; },
          ];
        }
      ];

      LOG_THRESHOLD = "INFO";
    };
  };
}
