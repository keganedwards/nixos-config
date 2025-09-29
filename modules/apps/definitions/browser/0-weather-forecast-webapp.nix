{constants, ...}: {
  "weather-forecast" = {
    type = "flatpak";
    id = constants.defaultWebbrowserFlatpakId;
    key = "0";
    commandArgs = ''--new-window "https://forecast.weather.gov/MapClick.php?lat=35.9952&lon=-78.8995"'';
  };
}
