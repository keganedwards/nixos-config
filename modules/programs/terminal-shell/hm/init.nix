# /modules/programs/terminal-shell/hm/init.nix
{
  programs.fish = {
    shellInit = ''
      # Suppress welcome message
      set -g fish_greeting ""

      # Override RIPGREP_CONFIG_PATH to point to the correct user's home
      set -gx RIPGREP_CONFIG_PATH ~/.config/ripgrep/ripgreprc
    '';

    interactiveShellInit = ''
      # Initial directory listing on startup
      if not set -q __initial_listing_done
        set -g __initial_listing_done 1
        if command -q eza
          eza -la
        else if command -q ls
          ls -la
        end
        echo
      end

      # Custom key bindings for fzf functions
      function fish_user_key_bindings
        bind \ct fzf_file_widget_corrected
        bind \ec fzf_zoxide_changer_corrected
        bind \ed fzf_insert_dir_corrected
        bind \cr fzf_history_widget_corrected
      end
    '';
  };

  xdg.configFile."fish/conf.d/.keep".text = "";
}
