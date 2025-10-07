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

        -- DISABLE SSH AGENT - this is the fix
        config.mux_enable_ssh_agent = false
        
        -- Also disable multiplexing server to prevent any background persistence
        config.unix_domains = {}
        
        return config
      '';
    };
  };
}
