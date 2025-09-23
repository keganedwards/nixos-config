{flakeConstants, ...}: let
  # Use flakeConstants instead of importing constants.nix directly
  constants = flakeConstants;

  slurpBinPath = "${constants.screenshotUtilitySlurp}/bin/slurp";
  grimBinPath = "${constants.screenshotUtilityGrim}/bin/grim";
  wlCopyBinPath = "${constants.clipboardUtilityWlClipboard}/bin/wl-copy";
  dateBinPath = "${constants.generalUtilityCoreutils}/bin/date";
  mkdirBinPath = "${constants.generalUtilityCoreutils}/bin/mkdir";

  screenshotCommandRegionToClipboard = ''
    ${grimBinPath} -g "$(${slurpBinPath})" - | ${wlCopyBinPath}
  '';

  screenshotCommandRegionToFile = ''
    ${mkdirBinPath} -p "$HOME/Screenshots" && \
    ${grimBinPath} -g "$(${slurpBinPath})" "$HOME/Screenshots/screenshot-$(${dateBinPath} +%Y-%m-%d-%H%M%S).png"
  '';
in {
  config = {
    home.packages = [
      constants.screenshotUtilitySlurp
      constants.screenshotUtilityGrim
      constants.clipboardUtilityWlClipboard
      constants.generalUtilityCoreutils
    ];

    # Corrected path for Home Manager Sway configuration
    wayland.windowManager.sway = {
      # extraConfig is types.lines and will be merged automatically
      extraConfig = ''
        # --- Screenshots (from screenshot.nix module) ---
        bindsym mod4+Mod1+s   exec ${screenshotCommandRegionToClipboard}
        # CORRECTED: Changed from Shift+s to 'p' to avoid conflict with suspend
        bindsym mod4+Mod1+p   exec ${screenshotCommandRegionToFile}
      '';
    };
  };
}
