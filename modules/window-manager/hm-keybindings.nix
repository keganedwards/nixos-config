# File: ./hm-sway-keybindings.nix
{pkgs, ...}: let
  swayExitWithBraveKill = pkgs.writeShellScript "sway-exit-brave" ''
    ${pkgs.flatpak}/bin/flatpak kill com.brave.Browser 2>/dev/null || true

    for i in {1..20}; do
      if ! ${pkgs.flatpak}/bin/flatpak ps --columns=application 2>/dev/null | ${pkgs.ripgrep}/bin/rg -q "com.brave.Browser"; then
        break
      fi
      sleep 0.1
    done

    ${pkgs.sway}/bin/swaymsg exit
  '';
in {
  # --- General Sway Keybindings ---
  wayland.windowManager.sway.config.keybindings = {
    # Window management
    "mod4+w" = "kill";

    # Volume control
    "mod4+bracketright" = "exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
    "mod4+bracketleft" = "exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
    "mod4+m" = "exec ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";

    # Media player control
    "mod4+space" = "exec ${pkgs.playerctl}/bin/playerctl play-pause";
    "mod4+Mod1+Right" = "exec ${pkgs.playerctl}/bin/playerctl next";
    "mod4+Mod1+Left" = "exec ${pkgs.playerctl}/bin/playerctl previous";

    # Custom script shortcuts
    "mod4+Shift+v" = "exec sway-sink-volume";
    "mod4+Shift+m" = "exec sway-mic-volume";
    "mod4+Shift+i" = "exec sway-source-volume";
    "mod4+Shift+w" = "exec sway-wifi-status";
    "mod4+Shift+b" = "exec sway-battery-status";
    "mod4+Shift+t" = "exec sway-show-time";
    "mod4+Shift+r" = "exec sway-reload-env";

    # Power management shortcuts (mod4+alt+shift+key)
    "mod4+Mod1+Shift+l" = "exec sway-lock-secure";
    "mod4+Mod1+Shift+s" = "exec systemctl suspend";
    "mod4+Mod1+Shift+h" = "exec systemctl hibernate";
    "mod4+Mod1+Shift+e" = "exec ${swayExitWithBraveKill}";
  };

  # Package the script so it's available
  home.packages = [
    (pkgs.writeShellScriptBin "sway-exit-safe" ''
      exec ${swayExitWithBraveKill}
    '')
  ];
}
