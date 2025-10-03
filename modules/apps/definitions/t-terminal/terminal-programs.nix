{
  username,
  pkgs,
  ...
}: {
  home-manager.users.${username} = {
    programs.wezterm = {
      enable = true;
      extraConfig = ''
        local wezterm = require 'wezterm'
        local config = {}

        -- Catppuccin Latte color scheme
        config.color_scheme = 'Catppuccin Latte'

        -- Hide tab bar with single tab
        config.hide_tab_bar_if_only_one_tab = true

        -- Tab bar settings
        config.use_fancy_tab_bar = false
        config.tab_bar_at_bottom = true

        -- Font configuration
        config.font_size = 11.0

        return config
      '';
    };
  };
}
