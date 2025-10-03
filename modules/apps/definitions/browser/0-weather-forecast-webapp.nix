{config, ...}: {
  config.rawAppDefinitions."weather-forecast" = {
    type = "flatpak";
    id = config.browserConstants.defaultFlatpakId;
    key = "0";
    commandArgs = ''--new-window "https://forecast.weather.gov/MapClick.php?lat=35.9952&lon=-78.8995"'';
  };
}
