# modules/home-manager/apps/definitions/browser/3-discord-pwa.nix
{
  type = "pwa";
  id = "https://discord.com/app"; # URL is the ID for PWAs
  appId = "brave-discord.com__app-Default"; # Explicit, observed Sway app_id
  key = "3";
  autostartPriority = 2;
}
