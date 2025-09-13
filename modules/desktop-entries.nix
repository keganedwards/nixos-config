# modules/home-manager/desktop-entries.nix
{
  config,
  lib,
  pkgs,
  ...
}: let
  sanitizeForFilename = str:
    if str == null || str == ""
    then throw "sanitizeForFilename received null or empty input"
    else lib.strings.sanitizeDerivationName str;

  getRawExecCommand = appConfig: let
    rawLaunchCommand = appConfig.launchCommand or null;
  in
    if rawLaunchCommand != null && lib.isString rawLaunchCommand && rawLaunchCommand != ""
    then
      if lib.hasPrefix "exec " rawLaunchCommand
      then lib.removePrefix "exec " rawLaunchCommand
      else rawLaunchCommand
    else null;

  appsToGenerate =
    lib.filter
    (item: let
      appCfg = item.appConfig;
      desktopCfg = appCfg.desktopFile or {};
      generateCondition = desktopCfg.generate or false;
      commandCondition = (getRawExecCommand appCfg) != null;
    in
      generateCondition && commandCondition)
    (lib.mapAttrsToList (appKey: appCfg: {
      inherit appKey;
      appConfig = appCfg;
    }) (config.applications or {}));

  # Collect MIME associations from all apps
  collectMimeAssociations = let
    allApps = config.applications or {};

    # For each app that wants to be a default handler
    defaultHandlerEntries = lib.flatten (
      lib.mapAttrsToList (
        appKey: appCfg: let
          desktopCfg = appCfg.desktopFile or {};
          mimeTypes = desktopCfg.defaultAssociations or [];
          isDefault = desktopCfg.isDefaultHandler or false;
          appInfo = appCfg.appInfo or {};
          displayName = desktopCfg.displayName or appInfo.name or appKey;
          desktopFileName = "${sanitizeForFilename displayName}.desktop";
        in
          if isDefault && mimeTypes != [] && (desktopCfg.generate or false)
          then
            map (mimeType: {
              inherit mimeType;
              desktop = desktopFileName;
            })
            mimeTypes
          else []
      )
      allApps
    );

    # Group by MIME type (in case multiple apps claim the same type)
    groupedByMime = builtins.groupBy (entry: entry.mimeType) defaultHandlerEntries;

    # Take the last one for each MIME type (later definitions win)
    defaultApplications =
      lib.mapAttrs (
        _mime: entries:
          if entries != []
          then (lib.last entries).desktop
          else null
      )
      groupedByMime;

    # Also create added associations (all apps that handle a mime type)
    addedAssociations = let
      allHandlers = lib.flatten (
        lib.mapAttrsToList (
          appKey: appCfg: let
            desktopCfg = appCfg.desktopFile or {};
            mimeTypes = desktopCfg.defaultAssociations or [];
            appInfo = appCfg.appInfo or {};
            displayName = desktopCfg.displayName or appInfo.name or appKey;
            desktopFileName = "${sanitizeForFilename displayName}.desktop";
          in
            if mimeTypes != [] && (desktopCfg.generate or false)
            then
              map (mimeType: {
                inherit mimeType;
                desktop = desktopFileName;
              })
              mimeTypes
            else []
        )
        allApps
      );
      grouped = builtins.groupBy (entry: entry.mimeType) allHandlers;
    in
      lib.mapAttrs (
        _mime: entries:
          lib.unique (map (e: e.desktop) entries)
      )
      grouped;
  in {
    inherit defaultApplications addedAssociations;
  };

  mimeAssociations = collectMimeAssociations;

  fileEntries =
    lib.map
    (item: let
      appCfg = item.appConfig;
      inherit (appCfg) appInfo;
      desktopCfg = appCfg.desktopFile;
      _nameSourceForFilename = desktopCfg.displayName or appInfo.name or item.appKey;
      baseFileName = sanitizeForFilename _nameSourceForFilename;
      wrapperScriptName = "run-${baseFileName}";
      wrapperScriptPath = ".local/bin/${wrapperScriptName}";
      fullWrapperScriptPath = "${config.home.homeDirectory}/${wrapperScriptPath}";
      commandToExecuteInWrapper = getRawExecCommand appCfg;
      isTerminalApp = appInfo.isTerminalApp or false;

      wrapperScriptContent =
        if isTerminalApp
        then ''
          #!${pkgs.runtimeShell}
          set -e
          ${commandToExecuteInWrapper} "$@"
        ''
        else ''
          #!${pkgs.runtimeShell}
          set -e
          nohup setsid ${commandToExecuteInWrapper} "$@" >/dev/null 2>&1 </dev/null &
          exit 0
        '';

      desktopFileName = "${baseFileName}.desktop";
      desktopFilePath = ".local/share/applications/${desktopFileName}";

      listToSemicolonString = listInput:
        if !lib.isList listInput
        then ""
        else let
          validStrings = lib.filter (elem: elem != null && lib.isString elem && elem != "") listInput;
        in
          if validStrings == []
          then ""
          else lib.concatStringsSep ";" validStrings + ";";

      mimeTypeString = listToSemicolonString (desktopCfg.defaultAssociations or []);
      categoriesString = listToSemicolonString (desktopCfg.categories or ["Utility"]);
      execArgPlaceholder =
        if mimeTypeString != ""
        then " %U"
        else "";
      startupWmClassValueRaw = appInfo.appId or "";
      startupWmClassValue =
        if lib.isList startupWmClassValueRaw
        then (lib.head startupWmClassValueRaw)
        else startupWmClassValueRaw;
      finalDisplayName = desktopCfg.displayName or appInfo.name or item.appKey;
      finalIconName = desktopCfg.iconName or appInfo.package or appInfo.name or "application-x-executable";
      comment = desktopCfg.comment or "Launch ${finalDisplayName}";

      desktopFileContent = ''
        [Desktop Entry]
        Version=1.0
        Type=Application
        Name=${finalDisplayName}
        ${lib.optionalString (desktopCfg ? "genericName" && desktopCfg.genericName != null) "GenericName=${desktopCfg.genericName}"}
        Comment=${comment}
        Exec=${fullWrapperScriptPath}${execArgPlaceholder}
        Icon=${finalIconName}
        Terminal=false
        ${lib.optionalString (mimeTypeString != "") "MimeType=${mimeTypeString}"}
        ${lib.optionalString (categoriesString != "") "Categories=${categoriesString}"}
        ${lib.optionalString (startupWmClassValue != "" && startupWmClassValue != null) "StartupWMClass=${startupWmClassValue}"}
      '';
    in [
      {
        name = wrapperScriptPath;
        value = {
          text = wrapperScriptContent;
          executable = true;
        };
      }
      {
        name = desktopFilePath;
        value = {text = desktopFileContent;};
      }
    ])
    appsToGenerate;
in {
  xdg.mimeApps = {
    enable = true;
    inherit (mimeAssociations) defaultApplications;
    associations.added = mimeAssociations.addedAssociations;
  };

  xdg.configFile."mimeapps.list".force = true;

  home = {
    packages = [
      pkgs.desktop-file-utils
      pkgs.xdg-utils
    ];

    file = lib.listToAttrs (lib.flatten fileEntries);

    activation = {
      updateDesktopDatabase = lib.hm.dag.entryAfter ["writeBoundary"] ''
        set -e
        mkdir -p "${config.home.homeDirectory}/.local/share/applications"

        if command -v update-desktop-database >/dev/null 2>&1; then
          echo "Updating desktop application database..."
          update-desktop-database -q "${config.home.homeDirectory}/.local/share/applications"
        else
          echo "Warning: update-desktop-database command not found. Skipping." >&2
        fi
      '';

      updateMimeDatabase = lib.hm.dag.entryAfter ["updateDesktopDatabase"] ''
        set -e
        if command -v update-mime-database >/dev/null 2>&1; then
          echo "Updating MIME database..."
          mkdir -p "${config.home.homeDirectory}/.local/share/mime"
          update-mime-database "${config.home.homeDirectory}/.local/share/mime" 2>/dev/null || true
        fi
      '';
    };
  };
}
