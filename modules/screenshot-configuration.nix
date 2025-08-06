# File: modules/home-manager/apps/screenshot.nix (as a Home Manager module)
{
  flakeConstants, # <<< NEW: Constants passed from flake
  ...
}: let
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
        bindsym mod4+s           exec ${screenshotCommandRegionToClipboard}
        bindsym mod4+Shift+s     exec ${screenshotCommandRegionToFile}
      '';
      # Ensure this module doesn't accidentally disable Sway if enabled elsewhere
      # enable = config.wayland.windowManager.sway.enable or false; # This line might cause issues if not handled carefully
      # Better to ensure enable = true is in the main config.
    };
  };
}
