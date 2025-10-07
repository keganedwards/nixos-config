{terminalConstants, ...}: {
  rawAppDefinitions.terminal = {
    type = "nix";
    id = terminalConstants.name;
    appId = terminalConstants.defaultAppId;
    key = "t";
  };
}
