{
  config, # Full Home Manager config, includes processed config.applications
  lib,
  pkgs,
  ...
}: let
  # This file uses the logic you provided, which correctly handles GUI and
  # Terminal applications differently.
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

  fileEntries =
    lib.map
    (item: let
      appCfg = item.appConfig;
      appInfo = appCfg.appInfo;
      desktopCfg = appCfg.desktopFile;
      _nameSourceForFilename = desktopCfg.displayName or appInfo.name or item.appKey;
      baseFileName = sanitizeForFilename _nameSourceForFilename;
      wrapperScriptName = "run-${baseFileName}";
      wrapperScriptPath = ".local/bin/${wrapperScriptName}";
      fullWrapperScriptPath = "${config.home.homeDirectory}/${wrapperScriptPath}";
      commandToExecuteInWrapper = getRawExecCommand appCfg;
      isTerminalApp = appInfo.isTerminalApp or false;

      # This is the key logic: a different wrapper for terminal vs. GUI apps.
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
  home.packages = [
    pkgs.desktop-file-utils
  ];

  home.file = lib.listToAttrs (lib.flatten fileEntries);

  home.activation.updateDesktopDatabase = lib.hm.dag.entryAfter ["writeBoundary"] ''
    set -e
    # Ensure the target directory exists before trying to update it.
    mkdir -p "${config.home.homeDirectory}/.local/share/applications"

    if command -v update-desktop-database >/dev/null 2>&1; then
      echo "Updating desktop application database..."
      update-desktop-database -q "${config.home.homeDirectory}/.local/share/applications"
    else
      echo "Warning: update-desktop-database command not found. Skipping." >&2
    fi
  '';
}
