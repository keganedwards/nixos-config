{config, ...}: {
  config.rawAppDefinitions."background-streams" = {
    type = "flatpak";
    id = config.browserConstants.defaultFlatpakId;
    commandArgs = ''--new-window "brave-twitch.tv__app-Default"'';
    key = "9";
  };
}
