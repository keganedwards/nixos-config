# modules/home-manager/apps/definitions/r-document-reader.nix
# apps/default.nix will derive the appKey (e.g., "rDocumentReader") from this filename.
# The content of this file IS the simplified configuration for that appKey.
{
  type = "flatpak"; # Tells apps/default.nix to use helpers.mkFlatpakApp

  # 'id' for Flatpaks is the Flatpak application ID.
  id = "org.gnome.Papers";

  key = "r"; # Sway keybinding hint
}
