{
  config,
  lib,
  pkgs,
  ...
}: let
  entries = lib.mapAttrsToList (
    _appKey: appConfig:
      if lib.isInt appConfig.autostartPriority && appConfig.launchCommand != null
      then {
        rawCmd = appConfig.launchCommand;
        priority = appConfig.autostartPriority;
        type = appConfig.type or "unknown";
      }
      else null
  ) (config.applications or {});

  sorted = lib.sort (a: b: a.priority < b.priority) (lib.filter (e: e != null) entries);

  # Calculate cumulative delay for PWAs
  addDelayToPwas = entries: let
    processEntries = acc: remaining:
      if remaining == []
      then acc.result
      else let
        current = builtins.head remaining;
        rest = builtins.tail remaining;

        newAcc =
          if current.type == "pwa"
          then {
            result =
              acc.result
              ++ [
                {
                  # This is the corrected line:
                  command = "sh -c '${pkgs.coreutils}/bin/sleep ${toString acc.pwaDelay} && ${current.rawCmd}'";
                }
              ];
            pwaDelay = acc.pwaDelay + 0.4; # Add cumulative delay for each PWA
          }
          else {
            result =
              acc.result
              ++ [
                {
                  command = current.rawCmd;
                }
              ];
            pwaDelay = acc.pwaDelay;
          };
      in
        processEntries newAcc rest;
  in
    processEntries {
      result = [];
      pwaDelay = 3; # Start with a 1 second base delay
    }
    entries;

  startupCommands = addDelayToPwas sorted;
in {
  # Assign commands to Sway's startup configuration
  wayland.windowManager.sway.config.startup =
    startupCommands
    ++ [
      {
        command = "swaymsg 'output * bg ${config.home.homeDirectory}/.local/share/wallpapers/Bing/desktop.jpg fill'";
      }
    ];
}
