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
  wayland.windowManager.sway.config.keybindings = {
    "mod4+Mod1+w" = "kill";

    "mod4+Mod1+bracketright" = "exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+";
    "mod4+Mod1+bracketleft" = "exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
    "Mod1+f10" = "exec ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";

    "Mod1+f11" = "exec ${pkgs.brightnessctl}/bin/brightnessctl set 5%-";
    "Mod1+f12" = "exec ${pkgs.brightnessctl}/bin/brightnessctl set 5%+";

    "mod4+Mod1+space" = "exec ${pkgs.playerctl}/bin/playerctl play-pause";
    "mod4+Mod1+Right" = "exec ${pkgs.playerctl}/bin/playerctl next";
    "mod4+Mod1+Left" = "exec ${pkgs.playerctl}/bin/playerctl previous";

    "mod4+Shift+v" = "exec sway-sink-volume";
    "mod4+Shift+m" = "exec sway-mic-volume";
    "Shift+insert" = "exec sway-source-volume";
    "mod4+Shift+w" = "exec sway-wifi-status";
    "mod4+Shift+b" = "exec sway-battery-status";
    "mod4+Shift+t" = "exec sway-show-time";
    "mod4+Shift+r" = "exec sway-reload-env";

    "Mod1+Shift+right" = "exec sway-lock-secure";
    "mod4+Mod1+Shift+s" = "exec systemctl suspend";
    "Mod1+Shift+down" = "exec systemctl hibernate";
    "Mod1+Shift+escape" = "exec ${swayExitWithBraveKill}";
  };

  home.packages = [
    (pkgs.writeShellScriptBin "sway-exit-safe" ''
      exec ${swayExitWithBraveKill}
    '')
    pkgs.brightnessctl
  ];
}
