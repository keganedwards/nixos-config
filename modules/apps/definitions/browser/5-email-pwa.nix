# modules/home-manager/apps/definitions/browser/5-email-pwa.nix
{
  type = "pwa";
  id = "https://mail.proton.me";
  appId = "brave-mail.proton.me__-Default"; # Explicit, observed Sway app_id
  key = "5";
  autostartPriority = 2;
}
