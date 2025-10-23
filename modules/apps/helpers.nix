{
  lib,
  pkgs,
  browserConstants,
  terminalConstants,
  mediaPlayerConstants,
  ...
}: {
  options.appHelpers = lib.mkOption {
    type = lib.types.attrs;
    default = rec {
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
        terminal = terminalConstants;
        mediaPlayer = mediaPlayerConstants;

        name = args.id;
        isTerminalApp = args.isTerminalApp or false;
        appIdFromArgs = args.appId or null;
        title = args.title or null;
        userLaunchCommand = args.launchCommand or null;
        userCommandArgs = args.commandArgs or "";
        cwdArg = let
          cwd = args.cwd or null;
        in
          if cwd != null
          then "--cwd ${lib.escapeShellArg cwd}"
          else "";

        finalCommandArgs = lib.trim (userCommandArgs + " " + cwdArg);
        isManagedExternally = args._isExplicitlyExternal or false;
        appType = args._appType or "nix";
        executablePathFromUser = args.executablePath or null;

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

        # Always use custom terminal appId when terminal supports it

        appId =
          if appIdFromArgs != null
          then appIdFromArgs
          else if isTerminalApp
          then "${terminal.name}-${baseAppId}"
          else baseAppId;

        defaultLaunchCommand =
          if isTerminalApp
          then
            if userLaunchCommand == null # Only construct if user didn't provide one
            then let
              # Use terminal launcher for terminal apps
              terminalLauncherCmd = "${terminal.terminalLauncher}/bin/terminal-launcher";
              appIdArg = "--app-id ${appId}";
              desktopArg =
                if args.key or null != null
                then "--desktop ${args.key}"
                else "";
              modeArg = "--generic"; # Default to generic mode
              execCmd = lib.escapeShellArg executableToRun;
              allArgs = lib.concatStringsSep " " (lib.filter (x: x != "") [
                modeArg
                appIdArg
                desktopArg
                execCmd
                finalCommandArgs
              ]);
            in "exec ${terminalLauncherCmd} ${allArgs}"
            else userLaunchCommand
          else if name == "mpv" && userLaunchCommand == null && mediaPlayer.bin != null
          then "exec ${mediaPlayer.bin}" + lib.optionalString (finalCommandArgs != "") " ${finalCommandArgs}"
          else "exec ${lib.escapeShellArg executableToRun}" + lib.optionalString (finalCommandArgs != "") " ${finalCommandArgs}";
        finalLaunchCommand =
          if userLaunchCommand != null
          then userLaunchCommand
          else defaultLaunchCommand;

        appInfo = {
          inherit name appId title installMethod isTerminalApp;
          package = appInfoPackageField;
        };
      in {
        inherit appInfo;
        launchCommand = finalLaunchCommand;
        desktopFile = lib.recursiveUpdate (mkDefaultDesktopFileAttrs appInfo) (args.desktopFile or {});
      };

      mkWebPageApp = args: let
        browser = browserConstants;
        url = args.url or args.id or "";
        appIdFromArgs = args.appId or browser.defaultWmClass;
        userLaunchCommand = args.launchCommand or null;
        userCommandArgs = args.commandArgs or "";

        noProto = lib.removePrefix "https://" (lib.removePrefix "http://" url);
        host = builtins.elemAt (lib.splitString "/" noProto) 0;
        derivedDisplayName = "Web: ${host}";

        appInfo = {
          name = derivedDisplayName;
          appId = appIdFromArgs;
          installMethod = "none";
          package = "browser-webpage";
          title = null;
          isTerminalApp = false;
        };

        allCommandArgs = lib.trim ("--new-window " + userCommandArgs);

        defaultLaunchCommand = "exec ${pkgs.flatpak}/bin/flatpak run ${browser.defaultFlatpakId} ${allCommandArgs} ${lib.escapeShellArg url}";
      in {
        inherit appInfo;
        launchCommand =
          if userLaunchCommand != null
          then userLaunchCommand
          else defaultLaunchCommand;
        desktopFile = lib.recursiveUpdate (mkDefaultDesktopFileAttrs appInfo) (args.desktopFile or {});
      };

      mkBlankWorkspace = args: let
        workspaceName = args.workspaceName or args.key or "blank";
        appInfo = {
          name = "Blank Workspace ${workspaceName}";
          appId = null;
          installMethod = "none";
          package = "blank-workspace";
          title = null;
          isTerminalApp = false;
        };
      in {
        inherit appInfo;
        launchCommand = null;
        desktopFile = mkDefaultDesktopFileAttrs appInfo;
      };

      mkFlatpakApp = args: let
        flatpakId = args.id;
        appIdFromArgs = args.appId or null;
        userLaunchCommand = args.launchCommand or null;
        commandArgs = args.commandArgs or "";

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
        browser = browserConstants;
        url = args.id or args.url or "";
        appIdFromArgs = args.appId or null;
        userLaunchCommand = args.launchCommand or null;
        noProto = lib.removePrefix "https://" (lib.removePrefix "http://" url);
        host = builtins.elemAt (lib.splitString "/" noProto) 0;
        derivedDisplayName = "PWA (${sanitize host "pwa-host"})";

        appIdForWM =
          if appIdFromArgs != null
          then appIdFromArgs
          else browser.defaultWmClass;

        appInfo = {
          name = derivedDisplayName;
          appId = appIdForWM;
          installMethod = "flatpak";
          package = browser.defaultFlatpakId;
          title = null;
          isTerminalApp = false;
        };

        defaultLaunchCommand = "exec ${pkgs.flatpak}/bin/flatpak run ${browser.defaultFlatpakId} --app=${lib.escapeShellArg url}";
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
    };
  };
}
