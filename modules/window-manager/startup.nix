{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  wmConstants = config.windowManagerConstants;
  processedApps = config.applications or {};

  entries =
    lib.mapAttrsToList (
      _appKey: appConfig:
        if appConfig.autostart or false
        then {
          rawCmd = appConfig.autostartCommand;
          type = appConfig.type or "unknown";
        }
        else null
    )
    processedApps;

  validEntries = lib.filter (e: e != null && e.rawCmd != null) entries;

  addDelayAndSpacing = entries: let
    processEntries = acc: remaining:
      if remaining == []
      then acc.result
      else let
        current = builtins.head remaining;
        rest = builtins.tail remaining;

        # Only PWAs get startup delays
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
            pwaDelay = acc.pwaDelay + 1.5;  # Stagger PWAs by 1.5 seconds each
            lastDelay = acc.lastDelay;
          }
          else {
            # Non-PWA apps launch immediately
            result =
              acc.result
              ++ [
                {
                  command = current.rawCmd;
                }
              ];
            pwaDelay = acc.pwaDelay;
            lastDelay = acc.lastDelay;
          };
      in
        processEntries newAcc rest;
  in
    processEntries {
      result = [];
      pwaDelay = 4;  # Start PWAs after 4 seconds, then increment
      lastDelay = 0;
    }
    entries;

  startupCommands = addDelayAndSpacing validEntries;
in {
  home-manager.users.${username} = wmConstants.setStartup startupCommands;
}
