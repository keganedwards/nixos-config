{config, ...}: {
  config.rawAppDefinitions."cloud-storage" = {
    type = "flatpak";
    id = config.browserConstants.defaultFlatpakId;
    key = "7";
    commandArgs = ''--new-window "https://drive.proton.me""'';
  };
}
