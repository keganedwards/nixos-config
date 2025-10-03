{config, ...}: {
  config.rawAppDefinitions."job" = {
    type = "flatpak";

    id = config.browserConstants.defaultFlatpakId;
    key = "j";
    commandArgs = "--new-window https://app.dataannotation.tech/workers/projects";
  };
}
