{config, ...}: {
  rawAppDefinitions.terminal = {
    type = "nix";
    id = config.terminalConstants.name;
    appId = "terminal";
    key = "t";
  };
}
