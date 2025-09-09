# File: ./hm-sway-keybindings.nix
{pkgs, ...}: {
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
    # Ensure these scripts are added to `home.packages` in another module
    "mod4+Shift+v" = "exec sway-sink-volume";
    "mod4+Shift+m" = "exec sway-mic-volume";
    "mod4+Shift+i" = "exec sway-source-volume";
    "mod4+Shift+w" = "exec sway-wifi-status";
    "mod4+Shift+b" = "exec sway-battery-status";
    "mod4+Shift+t" = "exec sway-show-time";
    "mod4+Shift+r" = "exec sway-reload-env";
  };
}
