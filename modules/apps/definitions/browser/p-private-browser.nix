{config, ...}: {
  config.rawAppDefinitions."tor" = {
    type = "flatpak";
    id = config.browserConstants.defaultFlatpakId;
    key = "p";
    commandArgs = "--tor";
  };
}
