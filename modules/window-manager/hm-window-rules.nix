{config, ...}: {
  wayland.windowManager.sway.extraConfig = ''
    # THIS LINE MUST BE REMOVED
    # output * bg ${config.home.homeDirectory}/.local/share/wallpapers/Bing/desktop.jpg fill

    # Set the default border style for new windows
    default_border none

    # Specific window rules
    for_window [app_id=".*"] border pixel 0
    for_window [class="steam_app*"] inhibit_idle focus
    for_window [class="(?i)fuzzel"] floating enable, resize set width 100 ppt height 100 ppt, move position center
  '';
}
