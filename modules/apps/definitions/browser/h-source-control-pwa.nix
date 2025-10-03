{config, ...}: {
  config.rawAppDefinitions."version-control" = {
    id = config.browserConstants.defaultFlatpakId;
    type = "flatpak";
    key = "h";
    commandArgs = ''--new-window "https://github.com"'';
  };
}
