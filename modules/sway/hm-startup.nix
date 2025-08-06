{
  config,
  lib,
  ...
}: let
  # Collect autostart entries from config.applications
  entries = lib.mapAttrsToList (
    appKey: appConfig:
    # Only include apps with an integer priority and launch command
      if lib.isInt appConfig.autostartPriority && appConfig.launchCommand != null
      then {
        rawCmd = appConfig.launchCommand;
        priority = appConfig.autostartPriority;
      }
      else null
  ) (config.applications or {});

  # Filter out null entries and sort by priority (lower numbers first)
  sorted = lib.sort (a: b: a.priority < b.priority) (lib.filter (e: e != null) entries);

  # Convert sorted entries directly to Sway startup commands
  startupCommands = map (e: {command = e.rawCmd;}) sorted;
in {
  # Assign commands to Sway's startup configuration
  wayland.windowManager.sway.config.startup = startupCommands;
}
