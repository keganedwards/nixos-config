{
  config.rawAppDefinitions."version-control" = {
    type = "flatpak";
    key = "h";
    commandArgs = ''--new-window "https://github.com"'';
  };
}
