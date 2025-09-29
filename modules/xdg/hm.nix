{
  config,
  lib,
  ...
}: let
  processedApps = config.applications or {};

  generateDefaultApps =
    lib.foldl' (
      acc: appKey: let
        appConfig = processedApps.${appKey};
        desktopConfig = appConfig.desktopFile or {};

        isValidForAssociation =
          desktopConfig ? "defaultAssociations"
          && lib.isList desktopConfig.defaultAssociations
          && desktopConfig.defaultAssociations != []
          && (desktopConfig.isDefaultHandler or false);

        targetDesktopFile =
          if !isValidForAssociation
          then null
          else if desktopConfig.generate or false
          then
            if desktopConfig ? "displayName" && lib.isString desktopConfig.displayName && desktopConfig.displayName != ""
            then "${lib.strings.sanitizeDerivationName desktopConfig.displayName}.desktop"
            else throw "App '${appKey}' has isDefaultHandler=true and generate=true but missing displayName"
          else if desktopConfig ? "targetDesktopFilename" && lib.isString desktopConfig.targetDesktopFilename && desktopConfig.targetDesktopFilename != ""
          then desktopConfig.targetDesktopFilename
          else throw "App '${appKey}' has isDefaultHandler=true but missing targetDesktopFilename";
      in
        if isValidForAssociation && targetDesktopFile != null
        then
          lib.foldl' (
            innerAcc: mimeType:
              innerAcc // {"${mimeType}" = [targetDesktopFile];}
          )
          acc
          desktopConfig.defaultAssociations
        else acc
    )
    {}
    (lib.attrNames processedApps);
in {
  xdg = {
    enable = true;
    mimeApps = {
      enable = true;
      defaultApplications = generateDefaultApps;
    };
  };
}
