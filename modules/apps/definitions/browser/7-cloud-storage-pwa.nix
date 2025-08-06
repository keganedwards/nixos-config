# modules/home-manager/apps/definitions/browser/7-cloud-storage-pwa.nix
{
  type = "pwa";
  id = "https://drive.proton.me";
  appId = "brave-drive.proton.me__-Default"; # Explicit, observed Sway app_id
  key = "7";
  # No autostartPriority.
}
