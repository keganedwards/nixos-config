{
  config,
  lib,
  pkgs,
  username,
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

  # Generate wrapper scripts as system packages
  wrapperPackages =
    lib.map (
      item: let
        appCfg = item.appConfig;
        inherit (appCfg) appInfo;
        desktopCfg = appCfg.desktopFile;
        _nameSourceForFilename = desktopCfg.displayName or appInfo.name or item.appKey;
        baseFileName = sanitizeForFilename _nameSourceForFilename;
        wrapperScriptName = "run-${baseFileName}";
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
      in
        pkgs.writeScriptBin wrapperScriptName wrapperScriptContent
    )
    appsToGenerate;

  # Generate desktop files
  desktopFiles = lib.listToAttrs (lib.map (item: let
      appCfg = item.appConfig;
      inherit (appCfg) appInfo;
      desktopCfg = appCfg.desktopFile;
      _nameSourceForFilename = desktopCfg.displayName or appInfo.name or item.appKey;
      baseFileName = sanitizeForFilename _nameSourceForFilename;
      wrapperScriptName = "run-${baseFileName}";
      desktopFileName = "${baseFileName}.desktop";

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

      desktopFileContent = pkgs.writeTextDir "share/applications/${desktopFileName}" ''
        [Desktop Entry]
        Version=1.0
        Type=Application
        Name=${finalDisplayName}
        ${lib.optionalString (desktopCfg ? "genericName" && desktopCfg.genericName != null) "GenericName=${desktopCfg.genericName}"}
        Comment=${comment}
        Exec=${wrapperScriptName}${execArgPlaceholder}
        Icon=${finalIconName}
        Terminal=false
        ${lib.optionalString (mimeTypeString != "") "MimeType=${mimeTypeString}"}
        ${lib.optionalString (categoriesString != "") "Categories=${categoriesString}"}
        ${lib.optionalString (startupWmClassValue != "" && startupWmClassValue != null) "StartupWMClass=${startupWmClassValue}"}
      '';
    in {
      name = desktopFileName;
      value = desktopFileContent;
    })
    appsToGenerate);

  # Collect MIME associations
  collectMimeAssociations = let
    allApps = config.applications or {};

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

    groupedByMime = builtins.groupBy (entry: entry.mimeType) defaultHandlerEntries;

    defaultApplications =
      lib.mapAttrs (
        _mime: entries:
          if entries != []
          then (lib.last entries).desktop
          else null
      )
      groupedByMime;

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

  # Create mimeapps.list content
  mimeappsContent = let
    formatMimeEntry = mime: desktop: "${mime}=${desktop}";
    defaultSection = lib.concatStringsSep "\n" (
      lib.mapAttrsToList formatMimeEntry (lib.filterAttrs (_: v: v != null) mimeAssociations.defaultApplications)
    );
    formatAddedEntry = mime: desktops: "${mime}=${lib.concatStringsSep ";" desktops};";
    addedSection = lib.concatStringsSep "\n" (
      lib.mapAttrsToList formatAddedEntry mimeAssociations.addedAssociations
    );
  in ''
    [Default Applications]
    ${defaultSection}

    [Added Associations]
    ${addedSection}
  '';
in {
  config = {
    # Add wrapper scripts and desktop file utilities to system packages
    environment.systemPackages =
      wrapperPackages
      ++ (lib.attrValues desktopFiles)
      ++ [
        pkgs.desktop-file-utils
        pkgs.xdg-utils
        pkgs.shared-mime-info
      ];

    # Set up system-wide mime associations
    environment.etc."xdg/mimeapps.list" = lib.mkIf (mimeAssociations.defaultApplications != {} || mimeAssociations.addedAssociations != {}) {
      text = mimeappsContent;
    };

    # Ensure XDG directories exist and databases are updated
    system.activationScripts.updateDesktopDatabase = lib.stringAfter ["etc"] ''
      # Update system-wide desktop database
      if command -v update-desktop-database >/dev/null 2>&1; then
        echo "Updating system desktop database..."
        ${pkgs.desktop-file-utils}/bin/update-desktop-database -q /run/current-system/sw/share/applications || true
      fi

      # Update MIME database
      if command -v update-mime-database >/dev/null 2>&1; then
        echo "Updating system MIME database..."
        ${pkgs.shared-mime-info}/bin/update-mime-database /run/current-system/sw/share/mime || true
      fi
    '';

    # For home-manager integration, still provide user-specific settings
    home-manager.users.${username} = {
      # FIX: Combine all xdg settings into a single block
      xdg = {
        enable = true;
        mime.enable = true;
        # Link to system mimeapps.list if user doesn't have their own
        configFile."mimeapps.list" = lib.mkDefault {
          # FIX: Use inherit for the source assignment
          inherit (config.environment.etc."xdg/mimeapps.list") source;
          force = true;
        };
      };
    };
  };
}
