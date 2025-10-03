{
  config,
  pkgs,
  username,
  lib,
  ...
}: let
  wm = config.windowManagerConstants;

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
in {
  home-manager.users.${username} = lib.mkMerge [
    {
      home.packages = [
        pkgs.slurp
        pkgs.grim
        pkgs.wl-clipboard
        pkgs.coreutils
      ];
    }

    (wm.setKeybindings {
      "mod4+Mod1+s" = "exec ${screenshotCommandRegionToClipboard}";
      "mod4+Mod1+p" = "exec ${screenshotCommandRegionToFile}";
    })
  ];
}
