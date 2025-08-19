# modules/home-manager/apps/helpers.nix
{
  lib,
  pkgs,
  constants,
  config, # The final Home Manager config object, passed from apps/default.nix
  ...
}: let
  inherit (constants) terminalBin terminalName pwaRunnerFlatpakId videoPlayerBin;
  resolve = val:
    if lib.isFunction val
    then val config
    else val;
  sanitize = str: defaultVal:
    if str == null || str == ""
    then lib.strings.sanitizeDerivationName defaultVal
    else lib.strings.sanitizeDerivationName str;
  deriveIconName = appInfo:
    if appInfo.package != null && appInfo.package != ""
    then appInfo.package
    else if appInfo.name != null && appInfo.name != ""
    then (sanitize appInfo.name "application")
    else "application-x-executable";
  mkDefaultDesktopFileAttrs = appInfo: let
    appNameOrDefault =
      if appInfo ? "name" && appInfo.name != null && appInfo.name != ""
      then appInfo.name
      else "Application";
  in {
    generate = false;
    displayName = appNameOrDefault;
    comment = "Launch " + appNameOrDefault;
    iconName = deriveIconName appInfo;
    categories = ["Utility"];
    defaultAssociations = [];
    isDefaultHandler = false;
    desktopExecArgs = null;
    targetDesktopFilename = null;
  };
in {
  # --- Generic App Helper ---
  mkApp = args: let
    name = resolve args.id;
    isTerminalAppFromArgs = resolve (args.isTerminalApp or false);
    appIdFromArgs = resolve (args.appId or null);
    title = resolve (args.title or null);
    userLaunchCommand = resolve (args.launchCommand or null);
    userCommandArgs = resolve (args.commandArgs or "");
    cwdArg = let
      cwd = resolve (args.cwd or null);
    in
      if cwd != null
      then "--cwd ${lib.escapeShellArg cwd}"
      else "";
    finalCommandArgs = lib.trim (userCommandArgs + " " + cwdArg);
    homePackagesFromArgs = resolve (args.appDefHomePackages or []);

    # --- THIS IS THE CORRECTED LINE ---
    # This now correctly uses the flag passed from default.nix,
    # making the "externally-managed" default work as intended.
    isManagedExternally = resolve (args._isExplicitlyExternal or false);

    executablePathFromUser = resolve (args.executablePath or null);
    installMethod =
      if isManagedExternally
      then "none"
      else if homePackagesFromArgs != []
      then "nix-via-homePackages"
      else if executablePathFromUser != null
      then "nix-custom-path"
      else if pkgs ? "${name}" && lib.isDerivation pkgs."${name}"
      then "nix-package"
      else "none";
    appInfoPackageField =
      if installMethod == "nix-package"
      then name
      else sanitize name "application";
    executableToRun =
      if executablePathFromUser != null
      then executablePathFromUser
      else if installMethod == "nix-package"
      then lib.getExe pkgs."${name}"
      else name;
    baseAppId = sanitize name "unknown-app";
    appId =
      if appIdFromArgs != null
      then appIdFromArgs
      else if isTerminalAppFromArgs
      then "${constants.terminalName}-${baseAppId}"
      else baseAppId;

    defaultLaunchCommand =
      if isTerminalAppFromArgs
      then let
        fullTerminalCommand = "${lib.escapeShellArg terminalBin} --app-id=${lib.escapeShellArg appId} ${lib.escapeShellArg executableToRun} ${finalCommandArgs} \"$@\"";
      in "exec sh -c '${fullTerminalCommand} &'"
      else if name == "mpv" && userLaunchCommand == null && constants.videoPlayerBin != null
      then "exec ${constants.videoPlayerBin}" + lib.optionalString (finalCommandArgs != "") " ${finalCommandArgs}"
      else "exec ${lib.escapeShellArg executableToRun}" + lib.optionalString (finalCommandArgs != "") (" " + finalCommandArgs);

    finalLaunchCommandValue =
      if args.vpn.enabled or false
      then "exec launch-vpn-app ${name}"
      else if userLaunchCommand != null
      then userLaunchCommand
      else defaultLaunchCommand;

    appInfo = {
      inherit name appId title installMethod;
      package = appInfoPackageField;
      isTerminalApp = isTerminalAppFromArgs;
    };
    userDesktopFileCfg = args.desktopFile or {};
  in {
    inherit appInfo;
    homePackages = homePackagesFromArgs;
    launchCommand = finalLaunchCommandValue;
    desktopFile = lib.recursiveUpdate (mkDefaultDesktopFileAttrs appInfo) userDesktopFileCfg;
  };

  # --- Flatpak App Helper (Unchanged) ---
  mkFlatpakApp = args: let
    flatpakId = resolve args.id;
    appIdFromArgs = resolve (args.appId or null);
    userLaunchCommand = resolve (args.launchCommand or null);
    commandArgs = resolve (args.commandArgs or "");
    appInfo = {
      name = flatpakId;
      appId =
        if appIdFromArgs != null
        then appIdFromArgs
        else flatpakId;
      installMethod = "flatpak";
      package = flatpakId;
      title = null;
      isTerminalApp = false;
    };
    defaultLaunchCommand = "exec ${pkgs.flatpak}/bin/flatpak run ${flatpakId}" + (lib.optionalString (commandArgs != "") " ${commandArgs}");
    finalLaunchCommandValue =
      if args.vpn.enabled or false
      then "exec launch-vpn-app ${flatpakId}"
      else if userLaunchCommand != null
      then userLaunchCommand
      else defaultLaunchCommand;
    userDesktopFileCfg = args.desktopFile or {};
  in {
    inherit appInfo;
    launchCommand = finalLaunchCommandValue;
    homePackages = args.appDefHomePackages or [];
    desktopFile =
      lib.recursiveUpdate
      ((mkDefaultDesktopFileAttrs appInfo)
        // {
          iconName = flatpakId;
          targetDesktopFilename = "${lib.strings.sanitizeDerivationName flatpakId}.desktop";
        })
      userDesktopFileCfg;
  };

  # --- PWA Helper (Unchanged) ---
  mkWebbrowserPwaApp = args: let
    url = resolve (args.id or args.url or "");
    appIdFromArgs = resolve (args.appId or null);
    userLaunchCommand = resolve (args.launchCommand or null);
    pwaRunnerWmClass = constants.pwaRunnerWmClass or constants.pwaRunnerFlatpakId;
    noProto = lib.removePrefix "https://" (lib.removePrefix "http://" url);
    host = builtins.elemAt (lib.splitString "/" noProto) 0;
    derivedDisplayName = "PWA (${sanitize host "pwa-host"})";
    appIdForSway =
      if appIdFromArgs != null
      then appIdFromArgs
      else pwaRunnerWmClass;
    appInfo = {
      name = derivedDisplayName;
      appId = appIdForSway;
      installMethod = "flatpak";
      package = pwaRunnerFlatpakId;
      title = null;
      isTerminalApp = false;
    };
    defaultLaunchCommand = "exec ${pkgs.flatpak}/bin/flatpak run ${pwaRunnerFlatpakId} --app=${lib.escapeShellArg url}";
    userDesktopFileCfg = args.desktopFile or {};
  in {
    inherit appInfo;
    launchCommand =
      if userLaunchCommand != null
      then userLaunchCommand
      else defaultLaunchCommand;
    homePackages = args.appDefHomePackages or [];
    desktopFile =
      lib.recursiveUpdate
      ((mkDefaultDesktopFileAttrs appInfo)
        // {
          targetDesktopFilename = "${lib.strings.sanitizeDerivationName appInfo.appId}.desktop";
        })
      userDesktopFileCfg;
  };
}
