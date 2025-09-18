{
  lib,
  config, # The config for the current module evaluation
  pkgs,
  inputs,
  system,
  specialArgs ? {},
  ...
} @ topLevelModuleArgs: let
  constants =
    if specialArgs ? "flakeConstants" && specialArgs.flakeConstants != null
    then specialArgs.flakeConstants
    else throw "flakeConstants was not found or was null in specialArgs passed to the apps module!";

  helpersModuleArgs = {
    inherit lib pkgs inputs system specialArgs constants;
    inherit (topLevelModuleArgs) config;
  };
  helpers = import ./helpers.nix helpersModuleArgs;

  definitionFileContext = {
    inherit lib pkgs inputs system specialArgs config constants helpers;
  };

  appOptionDefinitionsFromFile = import ./options.nix {inherit lib pkgs;};

  # This now calls your new smart importer, which discovers all app definition
  # files and provides them as a single, merged attribute set.
  allImportedAttrs = import ./definitions/default.nix definitionFileContext;

  # --- This logic correctly separates app definitions from global configs ---

  listStyleApps = allImportedAttrs.appList or [];
  listStyleAppsAsAttrs = lib.listToAttrs (
    lib.imap0 (index: appDef: {
      name = "app-${toString index}-${lib.strings.sanitizeDerivationName (appDef.key or appDef.id or "unknown")}";
      value = appDef;
    })
    listStyleApps
  );

  isSimplifiedAppConfigValue = value:
    lib.isAttrs value
    && (value ? "type" || value ? "id" || value ? "launchCommand" || value ? "key");

  # This filters `allImportedAttrs` to find just the app definitions.
  keyedAppConfigsMap =
    lib.filterAttrs (
      name: value: let
        isGlobalKey = lib.elem name ["programs" "services" "home" "xdg" "wayland" "fonts" "gtk" "appList"];
      in
        !isGlobalKey && isSimplifiedAppConfigValue value
    )
    allImportedAttrs;

  simplifiedAppConfigsMap = keyedAppConfigsMap // listStyleAppsAsAttrs;

  # This extracts the global configs (like `programs.yazi`).
  otherGlobalConfigsFromAppDefs = lib.removeAttrs allImportedAttrs (lib.attrNames simplifiedAppConfigsMap ++ ["appList"]);

  # --- This logic processes the apps through the helpers ---

  processedApplications = lib.mapAttrs (appKey: rawSimplifiedConf: let
    customLaunchScriptDerivation =
      if rawSimplifiedConf ? "launchScript"
      then let
        scriptInfo = rawSimplifiedConf.launchScript;
        scriptTemplate = import scriptInfo.path;
        finalScriptArgs = scriptInfo.args // {inherit pkgs;};
      in
        scriptTemplate finalScriptArgs
      else null;

    appType = rawSimplifiedConf.type or "externally-managed";
    primaryIdValue =
      rawSimplifiedConf.id or (
        if (lib.elem appType ["externally-managed" "custom"]) && (rawSimplifiedConf ? "appId")
        then rawSimplifiedConf.appId
        else if (lib.elem appType ["externally-managed" "custom"]) && (rawSimplifiedConf ? "launchCommand")
        then appKey
        else appKey
      );
    helperArgs =
      {
        id = primaryIdValue;
        _isExplicitlyExternal = appType == "externally-managed";
      }
      // rawSimplifiedConf;

    helperResult =
      if appType == "flatpak"
      then helpers.mkFlatpakApp helperArgs
      else if appType == "pwa"
      then helpers.mkWebbrowserPwaApp helperArgs
      else if appType == "nix" || appType == "externally-managed"
      then helpers.mkApp helperArgs
      else if appType == "custom" && (rawSimplifiedConf ? "launchCommand")
      then {
        appInfo = {
          name = primaryIdValue;
          appId = rawSimplifiedConf.appId or primaryIdValue;
          installMethod = "custom";
          package = primaryIdValue;
          title = null;
          isTerminalApp = rawSimplifiedConf.isTerminalApp or false;
        };
        inherit (rawSimplifiedConf) launchCommand;
        desktopFile = lib.recursiveUpdate (helpers.mkDefaultDesktopFileAttrs {
          name = primaryIdValue;
          package = primaryIdValue;
        }) (rawSimplifiedConf.desktopFile or {});
        homePackages = rawSimplifiedConf.appDefHomePackages or [];
      }
      else throw "Application '${appKey}' (type: \"${appType}\") is unhandled.";

    finalResult =
      if customLaunchScriptDerivation != null
      then lib.recursiveUpdate helperResult {launchCommand = "${customLaunchScriptDerivation}/bin/${customLaunchScriptDerivation.pname}";}
      else helperResult;

    autostartPriorityValue =
      if (rawSimplifiedConf ? "autostartPriority" && lib.isInt rawSimplifiedConf.autostartPriority)
      then rawSimplifiedConf.autostartPriority
      else null;
  in
    lib.recursiveUpdate finalResult {
      id = finalResult.appInfo.package or primaryIdValue;
      type = appType;
      key = rawSimplifiedConf.key or null;
      autostart = autostartPriorityValue != null;
      autostartPriority = autostartPriorityValue;
      inherit (finalResult) launchCommand;
      inherit (finalResult.appInfo) appId;
      appDefHomePackages = rawSimplifiedConf.appDefHomePackages or [];
      flatpakOverride = rawSimplifiedConf.flatpakOverride or null;
    })
  simplifiedAppConfigsMap;

  # --- This logic gathers all packages and Flatpaks ---

  packagesDerivedConfig = {
    applications = processedApplications;
    inherit pkgs lib;
    inherit (topLevelModuleArgs) config;
  };
  derivedPackagesInfo = import ./packages-app-derived.nix packagesDerivedConfig;

  appSpecificFlatpakOverrides = lib.foldl lib.recursiveUpdate {} (lib.mapAttrsToList (_appKey: appConfig:
    if appConfig.type == "flatpak" && appConfig.flatpakOverride != null && appConfig.appInfo.package != null
    then {"${appConfig.appInfo.package}" = appConfig.flatpakOverride;}
    else {})
  processedApplications);
in {
  # --- This section defines the final module output ---
  options =
    appOptionDefinitionsFromFile
    // {
      myConstants = lib.mkOption {
        type = lib.types.attrs;
        readOnly = true;
        description = "A set of common constants, provided by the apps module.";
      };
    };

  config = let
    resolveConfig = val:
      if lib.isFunction val
      then val topLevelModuleArgs.config
      else val;

    packagesFromProcessedApps = lib.flatten (lib.mapAttrsToList (_appKey: app: app.homePackages or []) processedApplications);
    resolvedOtherGlobals = lib.mapAttrs (_name: resolveConfig) otherGlobalConfigsFromAppDefs;

    directGlobalPackages = resolvedOtherGlobals.home.packages or [];
    globalFlatpakOverrides = resolvedOtherGlobals.services.flatpak.overrides or {};
    finalFlatpakOverrides = lib.recursiveUpdate globalFlatpakOverrides appSpecificFlatpakOverrides;

    # The final config merges everything together. The module system will correctly
    # combine the `home.file` definitions from `desktop-entries.nix` with any
    # that might exist in `resolvedOtherGlobals` (like your mpv symlinks).
    configLayers = [
      {myConstants = constants;}
      resolvedOtherGlobals
      {applications = processedApplications;}
      {home.packages = lib.unique (directGlobalPackages ++ packagesFromProcessedApps ++ derivedPackagesInfo.extractedNixPackages);}
      {services.flatpak.packages = lib.unique derivedPackagesInfo.extractedFlatpakIds;}
      {services.flatpak.overrides = finalFlatpakOverrides;}
    ];
  in
    lib.foldl lib.recursiveUpdate {} configLayers;
}
