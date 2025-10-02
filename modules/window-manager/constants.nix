{
  config,
  lib,
  pkgs,
  ...
}: let
  windowManager = {
    # Core commands
    msg = "${pkgs.sway}/bin/swaymsg";
    reload = "${pkgs.sway}/bin/swaymsg reload";
    exit = "${pkgs.sway}/bin/swaymsg exit";

    # Configuration path - this is what makes it swappable
    configPath = ["wayland" "windowManager" "sway" "config"];
    extraConfigPath = ["wayland" "windowManager" "sway" "extraConfig"];

    # Window rules and criteria helpers
    window = {
      criteriaByAppId = appId: {app_id = "^${lib.escapeRegex appId}$";};
      workspaceRule = appId: workspace: {
        command = "move container to workspace ${workspace}";
        criteria = windowManager.window.criteriaByAppId appId;
      };
    };

    # IPC and environment
    ipc = {
      getTree = "${windowManager.msg} -t get_tree";
      focusWindow = conId: "${windowManager.msg} \"[con_id=${conId}] focus\"";
    };

    # Session management
    session = {
      envVars = [
        "SWAYSOCK"
        "WAYLAND_DISPLAY"
        "XDG_CURRENT_DESKTOP"
        "XDG_SESSION_TYPE"
      ];
      desktopName = "sway";
      socketPath = "$XDG_RUNTIME_DIR/sway-ipc.$UID.$(${pkgs.procps}/bin/pgrep -x sway).sock";
    };

    # Lock screen
    lockScreen = {
      package = pkgs.swaylock;
      idlePackage = pkgs.swayidle;
      secureCommand = "sway-lock-secure";
      blockingCommand = "sway-lock-blocking";
    };
  };
in {
  options.windowManagerConstants = lib.mkOption {
    type = lib.types.attrs;
    default = windowManager;
  };

  config.windowManagerConstants = windowManager;
}
