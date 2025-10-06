{config, ...}: {
  rawAppDefinitions.terminal = {
    type = "nix";
    id = config.terminalConstants.name;
    appId = config.terminalConstants.defaultAppId;
    key = "t";
  };
}
