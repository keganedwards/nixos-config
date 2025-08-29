{constants, ...}: {
  type = "flatpak";
  id = constants.defaultWebbrowserFlatpakId;
  key = "h";
  commandArgs = ''--new-window "https://github.com"'';
}
