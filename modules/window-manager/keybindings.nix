{
  pkgs,
  windowManagerConstants,
  browserConstants,
  username,
  ...
}: let
  wm = windowManagerConstants;
  browser = browserConstants;

  exitWithBrowser = wm.scripts.makeExitWithBrowserKill browser.defaultFlatpakId;
in {
  imports = [
    (wm.setKeybindings {
      "Super+BracketRight" = ["${pkgs.wireplumber}/bin/wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"];
      "Super+BracketLeft" = ["${pkgs.wireplumber}/bin/wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"];
      "Super+m" = ["${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"];
      "Super+Shift+minus" = ["${pkgs.brightnessctl}/bin/brightnessctl" "set" "5%-"];
      "Super+Shift+equal" = ["${pkgs.brightnessctl}/bin/brightnessctl" "set" "5%+"];
      "Super+p" = ["${pkgs.playerctl}/bin/playerctl" "play-pause"];
      "Super+period" = ["${pkgs.playerctl}/bin/playerctl" "next"];
      "Super+comma" = ["${pkgs.playerctl}/bin/playerctl" "previous"];
      "Super+alt+s" = ["systemctl" "suspend"];
      "Super+alt+b" = ["systemctl" "hibernate"];
      "Super+alt+x" = ["${exitWithBrowser}"];
    })

    (wm.setActionKeybindings {
      "Super+w" = {close-window = {};};
      "Super+g" = {focus-column-left-or-last = {};};
    })

    (wm.setSettings wm.defaultSettings)
  ];

  home-manager.users.${username}.home.packages = [
    (pkgs.writeShellScriptBin wm.scripts.exitSafe ''
      exec ${exitWithBrowser}
    '')
    pkgs.brightnessctl
  ];
}
