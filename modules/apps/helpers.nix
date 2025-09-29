{
  lib,
  pkgs,
  constants,
  config,
  ...
}: let
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
    then sanitize appInfo.name "application"
    else "application-x-executable";

  mkDefaultDesktopFileAttrs = appInfo: let
    appName =
      if appInfo ? "name" && appInfo.name != null && appInfo.name != ""
      then appInfo.name
      else "Application";
  in {
    generate = false;
    displayName = appName;
    comment = "Launch " + appName;
    iconName = deriveIconName appInfo;
    categories = ["Utility"];
    defaultAssociations = [];
    isDefaultHandler = false;
    desktopExecArgs = null;
    targetDesktopFilename = null;
  };

  mkApp = args: let
    name = resolve args.id;
    isTerminalApp = resolve (args.isTerminalApp or false);
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
    isManagedExternally = resolve (args._isExplicitlyExternal or false);
    appType = resolve (args._appType or "nix");
    executablePathFromUser = resolve (args.executablePath or null);

    installMethod =
      if isManagedExternally
      then "none"
      else if executablePathFromUser != null
      then "nix-custom-path"
      else if appType == "nix"
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
      else if isTerminalApp
      then "${constants.terminalName}-${baseAppId}"
      else baseAppId;

    defaultLaunchCommand =
      if isTerminalApp
      then let
        fullCmd = "${lib.escapeShellArg constants.terminalBin} --app-id=${lib.escapeShellArg appId} ${lib.escapeShellArg executableToRun} ${finalCommandArgs} \"$@\"";
      in "exec sh -c '${fullCmd} &'"
      else if name == "mpv" && userLaunchCommand == null && constants.videoPlayerBin != null
      then "exec ${constants.videoPlayerBin}" + lib.optionalString (finalCommandArgs != "") " ${finalCommandArgs}"
      else "exec ${lib.escapeShellArg executableToRun}" + lib.optionalString (finalCommandArgs != "") " ${finalCommandArgs}";

    finalLaunchCommand =
      if userLaunchCommand != null
      then userLaunchCommand
      else defaultLaunchCommand;

    appInfo = {
      inherit name appId title installMethod;
      package = appInfoPackageField;
      isTerminalApp = isTerminalApp;
    };
  in {
    inherit appInfo;
    launchCommand = finalLaunchCommand;
    desktopFile = lib.recursiveUpdate (mkDefaultDesktopFileAttrs appInfo) (args.desktopFile or {});
  };

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

    defaultLaunchCommand = "exec ${pkgs.flatpak}/bin/flatpak run ${flatpakId}" + lib.optionalString (commandArgs != "") " ${commandArgs}";

    finalLaunchCommand =
      if userLaunchCommand != null
      then userLaunchCommand
      else defaultLaunchCommand;
  in {
    inherit appInfo;
    launchCommand = finalLaunchCommand;
    desktopFile =
      lib.recursiveUpdate
      (
        (mkDefaultDesktopFileAttrs appInfo)
        // {
          iconName = flatpakId;
          targetDesktopFilename = "${lib.strings.sanitizeDerivationName flatpakId}.desktop";
        }
      )
      (args.desktopFile or {});
  };

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
      package = constants.pwaRunnerFlatpakId;
      title = null;
      isTerminalApp = false;
    };

    defaultLaunchCommand = "exec ${pkgs.flatpak}/bin/flatpak run ${constants.pwaRunnerFlatpakId} --app=${lib.escapeShellArg url}";
  in {
    inherit appInfo;
    launchCommand =
      if userLaunchCommand != null
      then userLaunchCommand
      else defaultLaunchCommand;
    desktopFile =
      lib.recursiveUpdate
      (
        (mkDefaultDesktopFileAttrs appInfo)
        // {
          targetDesktopFilename = "${lib.strings.sanitizeDerivationName appInfo.appId}.desktop";
        }
      )
      (args.desktopFile or {});
  };
in {
  inherit mkDefaultDesktopFileAttrs mkApp mkFlatpakApp mkWebbrowserPwaApp;
}
