{pkgs, ...}: {
  home.file = {
    ".config/sway/base.conf".text = ''
      include ./keybindings.conf
      include ./input.conf

      exec sleep 5; systemctl --user start kanshi.service

      include /etc/sway/config.d/*

      for_window [app_id=".*"] border pixel 0
      for_window [class="steam_app*"] inhibit_idle focus
      for_window [class="(?i)fuzzel"] floating enable, resize set width 100 ppt height 100 ppt, move position center
      for_window [app_id="foot-clipse"] floating enable, resize set width 100 ppt height 100 ppt, move position center
    '';

    ".config/sway/input.conf".text = ''
      input * {
          accel_profile "flat"
          xkb_layout  "us"
          xkb_options "caps:none"
      }
    '';

    ".config/sway/keybindings.conf".text = ''

      bindsym mod4+w     kill

      bindsym mod4+bracketright exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
      bindsym mod4+bracketleft  exec ${pkgs.wireplumber}/bin/wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
      bindsym mod4+m exec ${pkgs.wireplumber}/bin/wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle

      bindsym mod4+space       exec ${pkgs.playerctl}/bin/playerctl play-pause
      bindsym mod4+Mod1+Right  exec ${pkgs.playerctl}/bin/playerctl next
      bindsym mod4+Mod1+Left   exec ${pkgs.playerctl}/bin/playerctl previous

      bindsym mod4+Shift+v     exec sway-sink-volume
      bindsym mod4+Shift+m     exec sway-mic-volume
      bindsym mod4+Shift+i     exec sway-source-volume
      bindsym mod4+Shift+w     exec sway-wifi-status
      bindsym mod4+Shift+b     exec sway-battery-status
      bindsym mod4+Shift+t     exec sway-show-time
      bindsym mod4+Shift+r     exec sway-reload-env
    '';
  };
}
