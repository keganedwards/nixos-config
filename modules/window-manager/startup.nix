{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  # Access system-level applications
  processedApps = config.applications or {};

  entries =
    lib.mapAttrsToList (
      _appKey: appConfig:
        if appConfig.autostart or false && appConfig.launchCommand != null
        then {
          rawCmd = appConfig.launchCommand;
          # Use autostartPriority if defined, otherwise default to 100
          priority = appConfig.autostartPriority or 100;
          type = appConfig.type or "unknown";
        }
        else null
    )
    processedApps;

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
                  command = "sh -c '${pkgs.coreutils}/bin/sleep ${toString acc.pwaDelay} && ${current.rawCmd}'";
                }
              ];
            pwaDelay = acc.pwaDelay + 1;
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
      pwaDelay = 7;
    }
    entries;

  startupCommands = addDelayToPwas sorted;
in {
  home-manager.users.${username} = {
    wayland.windowManager.sway.config.startup = startupCommands;
  };
}
