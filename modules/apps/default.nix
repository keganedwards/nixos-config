{
  lib,
  config,
  pkgs,
  inputs,
  specialArgs ? {},
  username,
  ...
}: let
  constants =
    if specialArgs ? "flakeConstants" && specialArgs.flakeConstants != null
    then specialArgs.flakeConstants
    else throw "flakeConstants not found in specialArgs";

  helpers = import ./helpers.nix {
    inherit lib pkgs config constants;
  };

  importedDefs = import ./definitions {
    inherit username lib pkgs config constants helpers inputs;
  };

  isAppDefinition = value:
    lib.isAttrs value
    && (value ? "type" || value ? "id" || value ? "launchCommand" || value ? "key");

  appDefs = lib.filterAttrs (_name: value: isAppDefinition value) importedDefs;
  otherConfigs = lib.filterAttrs (_name: value: !isAppDefinition value) importedDefs;

  processedApplications = lib.mapAttrs (appKey: rawConf: let
    customLaunchScript =
      if rawConf ? "launchScript"
      then
        (import rawConf.launchScript.path)
        (rawConf.launchScript.args // {inherit pkgs;})
      else null;

    # Auto-detect type based on ID if not explicitly provided
    autoDetectedType =
      if rawConf ? "type" && rawConf.type != null
      then rawConf.type
      else let
        idToCheck = rawConf.id or appKey;
        periodCount = lib.length (lib.filter (c: c == ".") (lib.stringToCharacters idToCheck));
      in
        if periodCount >= 2
        then "flatpak"
        else "nix";

    appType = autoDetectedType;

    primaryId =
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
      // rawConf;

    helperResult =
      if appType == "flatpak"
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
      inherit (finalResult) launchCommand;
      inherit (finalResult.appInfo) appId;
    })
  appDefs;

  packagesInfo = import ./packages-app-derived.nix {
    inherit lib pkgs;
    applications = processedApplications;
  };

  # Import desktop entries configuration
  desktopEntriesConfig = import ./desktop-entries.nix {
    inherit config lib pkgs username;
  };

  # Extract environment.systemPackages from otherConfigs if present
  otherSystemPackages = otherConfigs.environment.systemPackages or [];

  # Remove environment.systemPackages from otherConfigs to avoid conflicts
  otherConfigsWithoutSystemPackages =
    if otherConfigs ? "environment"
    then
      otherConfigs
      // {
        environment = builtins.removeAttrs otherConfigs.environment ["systemPackages"];
      }
    else otherConfigs;

  # Merge all system packages (including desktop utilities)
  allSystemPackages =
    packagesInfo.extractedNixPackages
    ++ otherSystemPackages
    ++ desktopEntriesConfig.environment.systemPackages;

  # Extract services.flatpak.packages from otherConfigs if present
  otherFlatpakPackages =
    if otherConfigs ? "services" && otherConfigs.services ? "flatpak" && otherConfigs.services.flatpak ? "packages"
    then otherConfigs.services.flatpak.packages
    else [];

  # Remove services.flatpak.packages from otherConfigs to avoid conflicts
  otherConfigsClean =
    if otherConfigsWithoutSystemPackages ? "services" && otherConfigsWithoutSystemPackages.services ? "flatpak"
    then
      otherConfigsWithoutSystemPackages
      // {
        services =
          otherConfigsWithoutSystemPackages.services
          // {
            flatpak = builtins.removeAttrs otherConfigsWithoutSystemPackages.services.flatpak ["packages"];
          };
      }
    else otherConfigsWithoutSystemPackages;

  # Merge all flatpak packages
  allFlatpakPackages = packagesInfo.extractedFlatpakIds ++ otherFlatpakPackages;

  # Merge desktop entries config, excluding packages we're handling separately
  desktopConfigWithoutPackages = builtins.removeAttrs desktopEntriesConfig ["environment"];
in {
  options = import ./options.nix {inherit lib;};

  imports = [
    desktopConfigWithoutPackages
  ];

  config =
    lib.recursiveUpdate {
      myConstants = constants;
      applications = processedApplications;
      environment.systemPackages = allSystemPackages;
      services.flatpak.packages = allFlatpakPackages;

      # Add the rest of desktop entries config
      inherit (desktopEntriesConfig) system;
      environment.etc = desktopEntriesConfig.environment.etc or {};
      home-manager = desktopEntriesConfig.home-manager or {};
    }
    otherConfigsClean;
}
