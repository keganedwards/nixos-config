{config, ...}: {
  config.rawAppDefinitions."browser" = {
    type = "flatpak";
    id = config.browserConstants.defaultFlatpakId;
    appId = config.browserConstants.defaultWmClass;
    key = "b";
    ignoreWindowAssignment = true;  # This prevents automatic workspace assignment
  };
}
