{config, ...}: {
  config.rawAppDefinitions."bank" = {
    id = config.browserConstants.defaultFlatpakId;
    key = "k";
    commandArgs = "--new-window https://digital.fidelity.com/prgw/digital/login/full-page";
  };
}
