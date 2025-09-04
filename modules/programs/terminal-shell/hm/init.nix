{
  programs.fish = {
    # Shell initialization
    shellInit = ''
      # Suppress welcome message
      set -g fish_greeting ""

      # Load nix-your-shell if available
      if command -q nix-your-shell
        nix-your-shell fish | source
      end
    '';

    # Interactive shell initialization
    interactiveShellInit = ''
      # Initial directory listing on startup
      if not set -q __initial_listing_done
        set -g __initial_listing_done 1
        eza -la
        echo
      end

      # Custom key bindings for our corrected functions
      function fish_user_key_bindings
        bind \ct fzf_file_widget_corrected
        bind \ec fzf_zoxide_changer_corrected
        bind \ed fzf_insert_dir_corrected
        bind \cr fzf_history_widget_corrected
      end
    '';

    # Login shell initialization (tmux auto-start)
    loginShellInit = ''
      # Auto-start tmux
      if command -v tmux >/dev/null 2>&1; and not set -q TMUX
        if status is-interactive
          set parent_cmd (ps -p $fish_pid -o comm= 2>/dev/null || echo "")
          if not string match -q "*build*" "$parent_cmd"
            exec tmux -f ~/.config/tmux/tmux.conf new-session -A -s default -c ~
          end
        end
      end
    '';
  };
}
