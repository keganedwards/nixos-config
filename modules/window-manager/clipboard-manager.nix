# File: modules/services/clipboard-manager.nix
{
  lib,
  pkgs,
  config,
  ...
}: let
  inherit (config.myConstants) terminalName;
  inherit (config.myConstants) terminalBin;
  clipseExe = lib.getExe pkgs.clipse;
  clipseSwayAppId = "clipse-${terminalName}";
  launchClipseCommand = "${terminalBin} --app-id=${lib.escapeShellArg clipseSwayAppId} ${clipseExe}";

  # Command to start the clipse listener daemon
  startClipseListener = "${clipseExe} --listen";
in {
  # 1. DO NOT enable the service. It runs in the wrong environment.
  # services.clipse.enable = true; # THIS IS THE PROBLEMATIC LINE

  # 2. Configure Sway to launch clipse
  wayland.windowManager.sway = {
    # Keep this enabled for proper session management
    systemd.enable = true;

    # Add extraConfig to launch the clipse listener on startup
    extraConfig = ''
      # Start the clipse listener daemon when sway starts
      exec ${startClipseListener}

      # Rule for Clipse UI (running in ${terminalName} with app_id ${clipseSwayAppId})
      # to float, cover screen, and center.
      for_window [app_id="${clipseSwayAppId}"] floating enable, resize set width 100 ppt height 100 ppt, move position center
    '';

    # Keybinding to launch the Clipse UI
    config.keybindings = lib.mkMerge [
      {
        "mod4+Shift+g" = "exec ${launchClipseCommand}";
      }
    ];
  };

  # 3. Explicitly add clipse to your user packages
  # Since the service is disabled, Home Manager won't add it automatically.
  home.packages = [pkgs.clipse];
}
