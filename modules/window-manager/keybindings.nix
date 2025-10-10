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
    # Spawn-based keybindings
    (wm.setKeybindings {
      "Mod+Alt+BracketRight" = ["${pkgs.wireplumber}/bin/wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"];
      "Mod+Alt+BracketLeft" = ["${pkgs.wireplumber}/bin/wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"];
      "Alt+F10" = ["${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"];
      "Alt+F11" = ["${pkgs.brightnessctl}/bin/brightnessctl" "set" "5%-"];
      "Alt+F12" = ["${pkgs.brightnessctl}/bin/brightnessctl" "set" "5%+"];
      "Mod+Alt+Space" = ["${pkgs.playerctl}/bin/playerctl" "play-pause"];
      "Mod+Alt+Right" = ["${pkgs.playerctl}/bin/playerctl" "next"];
      "Mod+Alt+Left" = ["${pkgs.playerctl}/bin/playerctl" "previous"];
      "Alt+Shift+Right" = ["niri-lock-secure"];
      "Mod+Alt+Shift+S" = ["systemctl" "suspend"];
      "Alt+Shift+Down" = ["systemctl" "hibernate"];
      "Alt+Shift+Escape" = ["${exitWithBrowser}"];
    })

    # Action-based keybindings
    (wm.setActionKeybindings {
      "Mod+Alt+W" = {close-window = {};};
      "Mod+Alt+Comma" = {focus-column-left-or-last = {};};
    })

    # Settings
    (wm.setSettings wm.defaultSettings)
  ];

  home-manager.users.${username}.home.packages = [
    (pkgs.writeShellScriptBin wm.scripts.exitSafe ''
      exec ${exitWithBrowser}
    '')
    pkgs.brightnessctl
  ];
}
