{constants, ...}: {
  "background-streams" = {
    type = "flatpak";
    id = constants.defaultWebbrowserFlatpakId;
    commandArgs = ''--new-window "brave-twitch.tv__app-Default"'';
    key = "9";
  };
}
