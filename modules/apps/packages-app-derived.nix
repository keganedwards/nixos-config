# modules/home-manager/apps/packages-app-derived.nix
{
  pkgs,
  lib,
  config, # This config contains the fully processed `config.applications` map
  ...
}: let
  # config.applications is the map: { "appKey1" = { id=..., type=..., appInfo=..., homePackages=...}, ... }
  actualApplicationsConfig = config.applications or {};

  # Function to extract package information from a single processed application configuration
  extractFromProcessedApp = appKey: appFullConfig: let
    # appInfo should always be present after processing by apps/default.nix and helpers
    appInfo = appFullConfig.appInfo or (throw "INTERNAL ERROR: Missing appInfo for appKey '${appKey}' in packages-app-derived.nix. App config: ${builtins.toJSON appFullConfig}");

    # Use appInfo.name (usually args.id from simplified config) or appKey for more informative error messages
    appNameForError = appInfo.name or appKey;

    installMethod = appInfo.installMethod or (throw "INTERNAL ERROR: Missing appInfo.installMethod for ${appKey}: ${appNameForError}");
    # appInfo.package is the identifier for installation (Nix attr name, Flatpak ID)
    packageIdentifierFromAppInfo = appInfo.package or (throw "INTERNAL ERROR: Missing appInfo.package for ${appKey}: ${appNameForError}");

    # These are packages that were listed in appDefHomePackages in the simplified config
    # and then included in the 'homePackages' attribute of the processed appFullConfig by the helper.
    directHomePackagesList = appFullConfig.homePackages or [];

    # Nix packages to install if installMethod is "nix-package"
    nixPkgsFromInstallMethod =
      if installMethod == "nix-package"
      then
        # Ensure the packageIdentifierFromAppInfo (which was args.id in this case) exists in pkgs
        lib.throwIf (!(pkgs ? "${packageIdentifierFromAppInfo}"))
        "Application Error ('${appNameForError}', appKey: ${appKey}): 'installMethod' is \"nix-package\" with package ID '${packageIdentifierFromAppInfo}', but this package is not found in your Nixpkgs set."
        # Return list with the actual package derivation
        [(pkgs."${packageIdentifierFromAppInfo}")]
      else []; # Not a "nix-package" type install, so no package derived this way

    # Flatpak IDs to install if installMethod is "flatpak"
    # This also covers PWAs where installMethod is "flatpak" and packageIdentifierFromAppInfo
    # would be the pwaRunnerFlatpakId.
    flatpakIdsFromInstallMethod =
      if installMethod == "flatpak"
      then [packageIdentifierFromAppInfo] # packageIdentifierFromAppInfo IS the Flatpak ID
      else [];
  in {
    # Combine Nix packages:
    # 1. Those from directHomePackagesList (originating from appDefHomePackages).
    # 2. The specific package if installMethod was "nix-package".
    nixPkgs = nixPkgsFromInstallMethod ++ directHomePackagesList;
    flatpakIds = flatpakIdsFromInstallMethod;
  };

  # Iterate over all defined applications and extract their package requirements
  allCollectedPackageInfo = lib.mapAttrsToList extractFromProcessedApp actualApplicationsConfig;

  # Consolidate and make unique all collected Nix packages and Flatpak IDs
  finalNixPkgsToInstall = lib.unique (lib.concatMap (info: info.nixPkgs or []) allCollectedPackageInfo);
  finalFlatpakIdsToInstall = lib.unique (lib.concatMap (info: info.flatpakIds or []) allCollectedPackageInfo);
in {
  # These are the final outputs of this module, consumed by apps/default.nix
  # to set home.packages and services.flatpak.packages.
  extractedNixPackages = finalNixPkgsToInstall;
  extractedFlatpakIds = finalFlatpakIdsToInstall;
}
