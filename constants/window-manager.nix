{
  pkgs,
  lib,
  ...
}: let
  windowManager = username: rec {
    name = "niri";

    # Core commands
    msg = "${pkgs.niri}/bin/niri msg";
    reload = "${pkgs.niri}/bin/niri msg reload-config";
    exit = "${pkgs.niri}/bin/niri msg action quit";
    quit = exit;

    # Configuration paths for accessing window manager config
    configPath = ["home-manager" "users" username "programs" "niri" "settings"];
    extraConfigPath = ["home-manager" "users" username "programs" "niri" "config"];

    # Helper to normalize keybind syntax for niri (always use Mod+Key format)
    normalizeKeybind = key:
      builtins.replaceStrings
      ["mod+" "Mod-" "mod-"]
      ["Mod+" "Mod+" "Mod+"]
      key;

    # Helper to set keybindings - returns an attrset that can be merged
    setKeybinding = key: command: {
      home-manager.users.${username}.programs.niri.settings.binds.${normalizeKeybind key}.action.spawn =
        if builtins.isList command
        then command
        else ["sh" "-c" command];
    };

    # Helper to set multiple keybindings - properly formatted for niri
    setKeybindings = bindings: {
      home-manager.users.${username}.programs.niri.settings.binds = lib.mapAttrs (_key: cmd: {
        action.spawn =
          if builtins.isList cmd
          then cmd
          else ["sh" "-c" cmd];
      }) (lib.mapAttrs' (k: v: lib.nameValuePair (normalizeKeybind k) v) bindings);
    };

    # Helper to set action keybindings (non-spawn actions like screenshot, close-window, etc)
    setActionKeybindings = bindings: {
      home-manager.users.${username}.programs.niri.settings.binds = lib.mapAttrs (_key: action: {
        inherit action;
      }) (lib.mapAttrs' (k: v: lib.nameValuePair (normalizeKeybind k) v) bindings);
    };

    # Helper to set extraConfig (for niri this is raw config text)
    setExtraConfig = config: {
      home-manager.users.${username}.programs.niri.config = config;
    };

    # Helper to set startup commands
    setStartup = commands: {
      home-manager.users.${username}.programs.niri.settings.spawn-at-startup =
        map (
          cmd:
            if builtins.isAttrs cmd && cmd ? command
            then cmd
            else {command = ["sh" "-c" cmd];}
        )
        commands;
    };

    # Helper to set window rules
    setWindowRules = rules: {
      home-manager.users.${username}.programs.niri.settings.window-rules = rules;
    };

    # Helper to set complete niri settings (for workspaces etc)
    setSettings = settings: {
      home-manager.users.${username}.programs.niri.settings = settings;
    };

    # Default niri settings
    defaultSettings = {
      hotkey-overlay.skip-at-startup = true;
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

      # Helper to create a fullscreen rule for an app
      fullscreenRule = appId: {
        matches = [{app-id = appId;}];
        default-column-width = {};
        open-fullscreen = true;
      };
    };

    # IPC and environment
    ipc = {
      # Get list of outputs/monitors
      getOutputs = "${msg} outputs";
      # Get windows
      getWindows = "${msg} windows";
      # Get workspaces
      getWorkspaces = "${msg} workspaces";
      # Focus a specific window
      focusWindow = id: "${msg} action focus-window --id ${id}";
      # Focus a workspace by name
      focusWorkspace = name: "${msg} action focus-workspace \"${name}\"";

      # Helper to check if a workspace ID has any windows
      workspaceHasWindows = workspaceId: ''
        if ${msg} windows | ${pkgs.ripgrep}/bin/rg -q "^\s*Workspace ID: ${workspaceId}$"; then
          echo "true"
        else
          echo "false"
        fi
      '';
    };

    # Wallpaper configuration for niri (using swaybg)
    wallpaper = {
      # Set wallpaper using swaybg
      set = path: "${pkgs.swaybg}/bin/swaybg -i ${path} -m fill";
      # Kill existing wallpaper daemon
      kill = "${pkgs.procps}/bin/pkill swaybg";
      # Reload wallpaper (kill and restart)
      reload = path: "sh -c '${pkgs.procps}/bin/pkill swaybg || true; ${pkgs.swaybg}/bin/swaybg -i ${path} -m fill &'";
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

    # Exit scripts
    scripts = {
      # Generic exit script name
      exitSafe = "wm-exit-safe";

      # Create exit script that kills browser before quitting
      makeExitWithBrowserKill = browserFlatpakId:
        pkgs.writeShellScript "wm-exit-with-browser" ''
          #!${pkgs.bash}/bin/bash
          ${pkgs.flatpak}/bin/flatpak kill ${browserFlatpakId} 2>/dev/null || true
          for i in {1..20}; do
            if ! ${pkgs.flatpak}/bin/flatpak ps --columns=application 2>/dev/null | ${pkgs.ripgrep}/bin/rg -q "${browserFlatpakId}"; then
              break
            fi
            sleep 0.1
          done
          ${quit}
        '';
    };

    # Combined config helper
    withConfig = attrs: {
      keybindings ? {},
      startup ? [],
      windowRules ? [],
      packages ? [],
      settings ? {},
      ...
    }:
      lib.mkMerge [
        attrs
        (
          if keybindings != {}
          then setKeybindings keybindings
          else {}
        )
        (
          if startup != []
          then setStartup startup
          else {}
        )
        (
          if windowRules != []
          then setWindowRules windowRules
          else {}
        )
        (
          if packages != []
          then {home-manager.users.${username}.home.packages = packages;}
          else {}
        )
        (
          if settings != {}
          then setSettings settings
          else {}
        )
      ];
  };
in
  windowManager
