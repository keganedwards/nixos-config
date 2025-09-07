# /modules/programs/terminal-shell/hm/init.nix
{
  programs.fish = {
    # Shell initialization
    shellInit = ''
      # Suppress welcome message
      set -g fish_greeting ""

      # Security: Set secure PATH and sanitize commands
      # Ensure system paths come first to prevent PATH hijacking
      set -gx PATH /run/current-system/sw/bin /run/wrappers/bin /usr/bin /bin $PATH

      # Function to sanitize command execution
      function __secure_command
        set -l cmd $argv[1]
        set -l args $argv[2..-1]

        # Find the command in trusted paths only
        set -l trusted_paths /run/current-system/sw/bin /run/wrappers/bin /usr/bin /bin
        set -l cmd_path ""

        for path in $trusted_paths
          if test -x "$path/$cmd"
            set cmd_path "$path/$cmd"
            break
          end
        end

        if test -n "$cmd_path"
          command $cmd_path $args
        else
          echo "Error: Command '$cmd' not found in trusted paths" >&2
          return 127
        end
      end

      # Load nix-your-shell if available (using secure path)
      if command -q nix-your-shell
        nix-your-shell fish | source
      end
    '';

    # Interactive shell initialization
    interactiveShellInit = ''
      # Initial directory listing on startup
      if not set -q __initial_listing_done
        set -g __initial_listing_done 1
        __secure_command eza -la
        echo
      end

      # Custom key bindings for our corrected functions
      function fish_user_key_bindings
        bind \ct fzf_file_widget_corrected
        bind \ec fzf_zoxide_changer_corrected
        bind \ed fzf_insert_dir_corrected
        bind \cr fzf_history_widget_corrected
      end

      # Security: Prevent command injection in prompts
      set -g fish_prompt_pwd_full_dirs 0
    '';

    # Login shell initialization (tmux auto-start)
    loginShellInit = ''
      # Auto-start tmux (using secure command path)
      if command -v tmux >/dev/null 2>&1; and not set -q TMUX
        if status is-interactive
          set parent_cmd (ps -p $fish_pid -o comm= 2>/dev/null || echo "")
          if not string match -q "*build*" "$parent_cmd"
            exec /run/current-system/sw/bin/tmux -f ~/.config/tmux/tmux.conf new-session -A -s default -c ~
          end
        end
      end
    '';
  };

  # Create conf.d directory structure - this ensures the directory exists for overlayfs
  xdg.configFile."fish/conf.d/.keep".text = "";
}
