{pkgs, ...}: {
  sms = {
    type = "externally-managed";
    id = "kdeconnect-sms";
    appId = "org.kde.kdeconnect.sms";
    key = "4";
    autostart = true;
  };
  environment.systemPackages = [pkgs.kdePackages.kpeople];
  programs.kdeconnect.enable = true;
}
