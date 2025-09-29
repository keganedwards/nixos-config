{constants, ...}: {
  "cloud-storage" = {
    type = "flatpak";
    id = constants.defaultWebbrowserFlatpakId;
    key = "7";
    commandArgs = ''--new-window "https://drive.proton.me""'';
  };
}
