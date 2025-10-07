{browserConstants, ...}: {
  config.rawAppDefinitions."browser" = {
    type = "flatpak";
    id = browserConstants.defaultFlatpakId;
    appId = browserConstants.defaultWmClass;
    key = "b";
    ignoreWindowAssignment = true;  # This prevents automatic workspace assignment
  };
}
