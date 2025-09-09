{
  config,
  lib,
  ...
}: let
  entries = lib.mapAttrsToList (
    _appKey: appConfig:
      if lib.isInt appConfig.autostartPriority && appConfig.launchCommand != null
      then {
        rawCmd = appConfig.launchCommand;
        priority = appConfig.autostartPriority;
      }
      else null
  ) (config.applications or {});

  sorted = lib.sort (a: b: a.priority < b.priority) (lib.filter (e: e != null) entries);

  startupCommands = map (e: {command = e.rawCmd;}) sorted;
in {
  # Assign commands to Sway's startup configuration
  wayland.windowManager.sway.config.startup =
    # Your existing startup commands
    startupCommands
    ++ [
      # ADD THIS COMMAND TO SET THE WALLPAPER AT RUNTIME
      {
        command = "swaymsg 'output * bg ${config.home.homeDirectory}/.local/share/wallpapers/Bing/desktop.jpg fill'";
      }
    ];
}
