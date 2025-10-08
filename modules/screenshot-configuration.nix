{
  pkgs,
  windowManagerConstants,
  ...
}: let
  slurpBinPath = "${pkgs.slurp}/bin/slurp";
  grimBinPath = "${pkgs.grim}/bin/grim";
  wlCopyBinPath = "${pkgs.wl-clipboard}/bin/wl-copy";
  dateBinPath = "${pkgs.coreutils}/bin/date";
  mkdirBinPath = "${pkgs.coreutils}/bin/mkdir";

  screenshotCommandRegionToClipboard = ''
    ${grimBinPath} -g "$(${slurpBinPath})" - | ${wlCopyBinPath}
  '';

  screenshotCommandRegionToFile = ''
    ${mkdirBinPath} -p "$HOME/Screenshots" && \
    ${grimBinPath} -g "$(${slurpBinPath})" "$HOME/Screenshots/screenshot-$(${dateBinPath} +%Y-%m-%d-%H%M%S).png"
  '';
in
  {
    environment.systemPackages = [
      pkgs.slurp
      pkgs.grim
      pkgs.wl-clipboard
      pkgs.coreutils
    ];
  }
  // windowManagerConstants.setKeybindings {
    "Mod+Alt+S" = screenshotCommandRegionToClipboard;
    "Mod+Alt+P" = screenshotCommandRegionToFile;
  }
