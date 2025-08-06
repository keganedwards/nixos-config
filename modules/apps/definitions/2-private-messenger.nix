# modules/home-manager/apps/definitions/2-signal.nix
# The filename "2-signal.nix" will be used by apps/default.nix
# to derive the appKey (e.g., "c2Signal" or "twoSignal").
# Its content IS the simplified application configuration.
{
  type = "flatpak";
  id = "org.signal.Signal"; # Primary identifier (Flatpak ID)

  key = "2"; # Sway keybinding hint

  # autostartPriority, if set to an integer, implies autostart = true.
  # The actual autostart = true/false boolean will be set by default.nix.
  autostartPriority = 10;
}
