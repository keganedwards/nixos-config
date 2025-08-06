# modules/home-manager/apps/definitions/browser/b-default-browser.nix
{constants, ...}:
# Only needs constants from the passed moduleArgs
{
  # The key for this app definition in config.applications will be derived
  # by apps/default.nix from this filename (e.g., "bDefaultBrowser").
  # This function returns the simplified configuration for that appKey.
  type = "flatpak";
  id = constants.defaultWebbrowserFlatpakId; # e.g., "com.brave.Browser"
  key = "b";
  # No explicit 'appId' field.
  # mkFlatpakApp will default appInfo.appId to the 'id' (constants.defaultWebbrowserFlatpakId).
  # This is typically correct for matching the main window of a Flatpak application.
}
