{pkgs, ...}: let
  niriExitWithBraveKill = pkgs.writeShellScript "niri-exit-brave" ''
    #!${pkgs.bash}/bin/bash
    ${pkgs.flatpak}/bin/flatpak kill com.brave.Browser 2>/dev/null || true

    for i in {1..20}; do
      if ! ${pkgs.flatpak}/bin/flatpak ps --columns=application 2>/dev/null | ${pkgs.ripgrep}/bin/rg -q "com.brave.Browser"; then
        break
      fi
      sleep 0.1
    done

    ${pkgs.niri}/bin/niri msg action quit
  '';
in {
  programs.niri = {
    settings = {
      hotkey-overlay.skip-at-startup = true;
      binds = {
        "Mod+Alt+W".action.close-window = {};
        "Mod+Alt+BracketRight".action.spawn = ["${pkgs.wireplumber}/bin/wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"];
        "Mod+Alt+BracketLeft".action.spawn = ["${pkgs.wireplumber}/bin/wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"];
        "Alt+F10".action.spawn = ["${pkgs.wireplumber}/bin/wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"];
        "Alt+F11".action.spawn = ["${pkgs.brightnessctl}/bin/brightnessctl" "set" "5%-"];
        "Alt+F12".action.spawn = ["${pkgs.brightnessctl}/bin/brightnessctl" "set" "5%+"];
        "Mod+Alt+Space".action.spawn = ["${pkgs.playerctl}/bin/playerctl" "play-pause"];
        "Mod+Alt+Right".action.spawn = ["${pkgs.playerctl}/bin/playerctl" "next"];
        "Mod+Alt+Left".action.spawn = ["${pkgs.playerctl}/bin/playerctl" "previous"];
        "Alt+Shift+Right".action.spawn = ["niri-lock-secure"];
        "Mod+Alt+Shift+S".action.spawn = ["systemctl" "suspend"];
        "Alt+Shift+Down".action.spawn = ["systemctl" "hibernate"];
        "Alt+Shift+Escape".action.spawn = ["${niriExitWithBraveKill}"];

        # Window navigation within current workspace
        "Mod+Tab".action.focus-window-right = {};
        "Mod+Shift+Tab".action.focus-window-left = {};

        # CORRECTED AND VERIFIED: Keybindings for vertical workspace management
        "Super+Ctrl+w".action.focus-workspace-up = {}; # Focus the workspace above
        "Super+Ctrl+s".action.focus-workspace-down = {}; # Focus the workspace below
        "Super+Ctrl+a".action.move-workspace-up = {}; # Move the current workspace up in the stack
        "Super+Ctrl+d".action.move-workspace-down = {}; # Move the current workspace down in the stack
      };
    };
  };

  home.packages = [
    (pkgs.writeShellScriptBin "niri-exit-safe" ''
      exec ${niriExitWithBraveKill}
    '')
    pkgs.brightnessctl
  ];
}
