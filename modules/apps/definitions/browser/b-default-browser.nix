{config, ...}: {
  config.rawAppDefinitions."browser" = {
    type = "flatpak";
    id = config.browserConstants.defaultFlatpakId;
    key = "b";
  };
}
