{
  lib,
  pkgs,
}: {
  windowManagerConstants = {
    name = "niri";
    
    # Core commands
    msg = "${pkgs.niri}/bin/niri msg";
    reload = "${pkgs.niri}/bin/niri msg reload-config";
    exit = "${pkgs.niri}/bin/niri msg quit";

    # Configuration paths for accessing window manager config
    configPath = ["programs" "niri" "settings"];
    extraConfigPath = ["programs" "niri" "config"];

    # Helper to set keybindings - returns an attrset that can be merged
    setKeybinding = key: command: {
      programs.niri.settings.binds.${key}.action.spawn = 
        if builtins.isList command
        then command
        else ["sh" "-c" command];
    };

    # Helper to set multiple keybindings - properly formatted for niri
    setKeybindings = bindings: {
      programs.niri.settings.binds = lib.mapAttrs (key: cmd: {
        action.spawn = 
          if builtins.isList cmd
          then cmd
          else ["sh" "-c" cmd];
      }) bindings;
    };

    # Helper to set extraConfig (for niri this is raw config text)
    setExtraConfig = config: {
      programs.niri.config = config;
    };

    # Helper to set startup commands
    setStartup = commands: {
      programs.niri.settings.spawn-at-startup = 
        map (cmd: 
          if builtins.isAttrs cmd && cmd ? command 
          then {command = ["sh" "-c" cmd.command];}
          else {command = ["sh" "-c" cmd];}
        ) commands;
    };

    # Window rules and criteria helpers
    window = {
      criteriaByAppId = appId: {
        matches = [{app-id = "^${lib.escapeRegex appId}$";}];
      };
      workspaceRule = appId: workspace: {
        matches = [{app-id = "^${lib.escapeRegex appId}$";}];
        open-on-workspace = workspace;
      };
    };

    # IPC and environment
    ipc = {
      getTree = "${pkgs.niri}/bin/niri msg windows";
      focusWindow = id: "${pkgs.niri}/bin/niri msg action focus-window --id ${id}";
    };

    # Session management
    session = {
      envVars = [
        "NIRI_SOCKET"
        "WAYLAND_DISPLAY"
        "XDG_CURRENT_DESKTOP"
        "XDG_SESSION_TYPE"
      ];
      desktopName = "niri";
      socketPath = "$XDG_RUNTIME_DIR/niri.socket";
    };
  };

  terminalConstants = {
    name = "wezterm";
    package = pkgs.wezterm;
    bin = "${pkgs.wezterm}/bin/wezterm";
    
    # Launch command for regular terminal instances
    defaultLaunchCmd = "${pkgs.wezterm}/bin/wezterm start";
    
    # Launch command when you need a custom app ID
    launchWithAppId = appId: "${pkgs.wezterm}/bin/wezterm start --class ${appId}";
    
    # Whether this terminal supports custom app IDs
    supportsCustomAppId = true;
    
    # Default app ID for terminal windows (wezterm uses org.wezfurlong.wezterm by default)
    defaultAppId = "org.wezfurlong.wezterm";
  };

  editorConstants = {
    appIdForWM = "nvim-editor-terminal";
    packageName = "neovim";
    iconName = "nvim";
  };

  mediaPlayerConstants = {
    package = pkgs.mpv;
    name = "mpv";
    bin = "${pkgs.mpv}/bin/mpv";
    appId = "mpv";
  };

  browserConstants = {
    defaultFlatpakId = "com.brave.Browser";
    defaultWmClass = "brave-browser";
    pwaRunnerFlatpakId = "com.brave.Browser";
    pwaRunnerWmClass = "Brave-browser";
  };
}
