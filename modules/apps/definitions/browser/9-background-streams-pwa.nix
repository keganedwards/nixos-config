# modules/home-manager/apps/definitions/browser/9-background-streams-pwa.nix
{
  type = "pwa";
  id = "https://www.twitch.tv/directory/all?sort=VIEWER_COUNT";
  appId = "brave-twitch.tv__app-Default"; # Explicit, observed Sway app_id
  key = "9";
  # No autostartPriority.
}
