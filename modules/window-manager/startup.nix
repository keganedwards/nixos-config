{
  config,
  lib,
  pkgs,
  windowManagerConstants,
  ...
}: let
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
                "sh -c '${pkgs.coreutils}/bin/sleep ${toString acc.pwaDelay} && ${current.rawCmd}'"
              ];
            pwaDelay = acc.pwaDelay + 2.5;
            # FIX 1: Use inherit
            inherit (acc) lastDelay;
          }
          else {
            # Non-PWA apps launch immediately
            result =
              acc.result
              ++ [
                current.rawCmd
              ];
            # FIX 2 & 3: Combine into a single inherit statement
            inherit (acc) pwaDelay lastDelay;
          };
      in
        processEntries newAcc rest;
  in
    processEntries {
      result = [];
      pwaDelay = 4; # Start PWAs after 4 seconds, then increment
      lastDelay = 0;
    }
    entries;

  startupCommands = addDelayAndSpacing validEntries;
in
  # setStartup already wraps in home-manager.users.${username}
  windowManagerConstants.setStartup startupCommands
