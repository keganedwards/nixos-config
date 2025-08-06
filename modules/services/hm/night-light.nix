{
  services.gammastep = {
    enable = true;
    temperature = {
      day = 6500; # typical daylight color temperature
      night = 1000;
    };
    provider = "manual";
    latitude = 35.994034;
    longitude = -78.898621;
    settings = {
      general = {
        adjustment-method = "wayland";
        brightness-night = "0.1";
      };
    };
  };
}
