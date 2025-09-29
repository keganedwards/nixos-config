{constants, ...}: {
  "bank" = {
    type = "flatpak";
    id = constants.defaultWebbrowserFlatpakId;
    key = "k";
    commandArgs = "--new-window https://digital.fidelity.com/prgw/digital/login/full-page";
  };
}
