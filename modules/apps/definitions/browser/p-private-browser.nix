{constants, ...}: {
  "tor" = {
    type = "flatpak";
    id = constants.defaultWebbrowserFlatpakId;
    key = "p";
    commandArgs = "--tor";
  };
}
