{
  services.kanshi = {
    enable = true;
    settings = [
      # Profile for laptop-only display
      {
        profile = {
          name = "laptop-only";
          outputs = [
            {
              criteria = "eDP-1";
              status = "enable";
              mode = "1920x1080";
            }
          ];
        };
      }
      # Profile for external display
      {
        profile = {
          name = "external-connected";
          outputs = [
            {
              criteria = "eDP-1";
              status = "disable";
            }
            {
              criteria = "HDMI-A-2";
              status = "enable";
              mode = "1920x1080@60Hz";
            }
          ];
        };
      }
    ];
  };
}
