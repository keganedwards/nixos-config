{
  lib,
  config,
  pkgs,
  username,
  ...
}: let
  helpers = config.appHelpers;

  isAppDefinition = value:
    lib.isAttrs value
    && (value ? "type" || value ? "id" || value ? "launchCommand" || value ? "key");

  # Get app definitions from config.rawAppDefinitions (set by individual app files)
  appDefs = lib.filterAttrs (_name: value: isAppDefinition value) (config.rawAppDefinitions or {});

  processedApplications = lib.mapAttrs (appKey: rawConf: let
    customLaunchScript =
      if rawConf ? "launchScript"
      then
        (import rawConf.launchScript.path)
        (rawConf.launchScript.args // {inherit pkgs;})
      else null;

    # Check for blank workspace
    isBlankWorkspace = 
      (rawConf.id or null) == null && 
      (rawConf.appId or null) == null && 
      (rawConf.title or null) == null &&
      (rawConf.url or null) == null &&
      (rawConf.launchCommand or null) == null &&
      (rawConf.key != null);

    autoDetectedType =
      if isBlankWorkspace
      then "blank"
      else if rawConf ? "type" && rawConf.type != null
      then rawConf.type
      else if rawConf ? "url" || (lib.hasPrefix "http" (rawConf.id or ""))
      then "web-page"
      else let
        idToCheck = rawConf.id or appKey;
        periodCount = lib.length (lib.filter (c: c == ".") (lib.stringToCharacters idToCheck));
      in
        if periodCount >= 2
        then "flatpak"
        else "nix";

    appType = autoDetectedType;

    primaryId =
      if isBlankWorkspace
      then "blank-${appKey}"
      else if appType == "web-page"
      then rawConf.url or rawConf.id or ""
      else
        rawConf.id
        or (
          if rawConf ? "appId"
          then rawConf.appId
          else appKey
        );

    helperArgs =
      {
        id = primaryId;
        _isExplicitlyExternal = appType == "externally-managed";
        _wantsNixInstall = appType == "nix";
      }
      // rawConf
      // (if appType == "web-page" && rawConf ? "url" then {url = rawConf.url;} else {});

    helperResult =
      if appType == "blank"
      then helpers.mkBlankWorkspace helperArgs
      else if appType == "web-page"
      then helpers.mkWebPageApp helperArgs
      else if appType == "flatpak"
      then helpers.mkFlatpakApp helperArgs
      else if appType == "pwa"
      then helpers.mkWebbrowserPwaApp helperArgs
      else if appType == "nix" || appType == "externally-managed"
      then helpers.mkApp helperArgs
      else if appType == "custom" && (rawConf ? "launchCommand")
      then {
        appInfo = {
          name = primaryId;
          appId = rawConf.appId or primaryId;
          installMethod = "custom";
          package = primaryId;
          title = null;
          isTerminalApp = rawConf.isTerminalApp or false;
        };
        inherit (rawConf) launchCommand;
        desktopFile =
          lib.recursiveUpdate
          (helpers.mkDefaultDesktopFileAttrs {
            name = primaryId;
            package = primaryId;
          })
          (rawConf.desktopFile or {});
      }
      else throw "Application '${appKey}' (type: ${appType}) is unhandled.";

    finalResult =
      if customLaunchScript != null
      then
        lib.recursiveUpdate helperResult {
          launchCommand = "${customLaunchScript}/bin/${customLaunchScript.pname}";
        }
      else helperResult;
  in
    lib.recursiveUpdate finalResult {
      id = finalResult.appInfo.package or primaryId;
      type = appType;
      key = rawConf.key or null;
      autostart = rawConf.autostart or false;
      autostartCommand = rawConf.autostartCommand or finalResult.launchCommand or "";
      workspaceName = rawConf.workspaceName or rawConf.swayWorkspace or (rawConf.key or null);
      ignoreWindowAssignment = rawConf.ignoreWindowAssignment or false;
      inherit (finalResult) launchCommand;
      inherit (finalResult.appInfo) appId;
    })
  appDefs;

  packagesInfo = import ./packages-app-derived.nix {
    inherit lib pkgs;
    applications = processedApplications;
  };
in {
  imports = [
    ./helpers.nix
    ./definitions
    ./options.nix
    ./desktop-entries.nix
  ];

  config = {
    applications = processedApplications;

    environment.systemPackages = packagesInfo.extractedNixPackages;
    services.flatpak.packages = packagesInfo.extractedFlatpakIds;
  };
}
