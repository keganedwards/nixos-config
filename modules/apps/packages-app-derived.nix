{
  lib,
  pkgs,
  applications,
}: let  # Remove the '...' since we don't use any other arguments
  extractFromApp = appKey: appConfig: let
    appInfo = appConfig.appInfo or (throw "Missing appInfo for ${appKey}");
    installMethod = appInfo.installMethod or (throw "Missing installMethod for ${appKey}");
    packageId = appInfo.package or (throw "Missing package for ${appKey}");

    nixPkgs =
      if installMethod == "nix-package"
      then [pkgs."${packageId}"]
      else [];

    flatpakIds =
      if installMethod == "flatpak"
      then [packageId]
      else [];
  in {
    inherit nixPkgs flatpakIds;
  };

  allPackageInfo = lib.mapAttrsToList extractFromApp applications;
  finalNixPackages = lib.unique (lib.concatMap (info: info.nixPkgs or []) allPackageInfo);
  finalFlatpakIds = lib.unique (lib.concatMap (info: info.flatpakIds or []) allPackageInfo);
in {
  extractedNixPackages = finalNixPackages;
  extractedFlatpakIds = finalFlatpakIds;
}
