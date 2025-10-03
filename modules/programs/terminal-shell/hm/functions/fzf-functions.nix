{
  programs.fish = {
    # It is crucial to define the function wrapper inside the Nix string.
    functions = {
      # Custom file widget function
      fzf_file_widget_corrected = ''
        function fzf_file_widget_corrected
          # Using an array for fd arguments is the most robust way
          # to ensure each exclusion is treated as a separate argument.
          set -l fd_args --type f --hidden
          set -a fd_args --exclude ".cache"
          set -a fd_args --exclude ".nix-profile"
          set -a fd_args --exclude ".local/state"
          set -a fd_args --exclude ".local/share/Steam"
          set -a fd_args --exclude ".nix-defexpr"
          set -a fd_args --exclude ".git"
          set -a fd_args --exclude "node_modules"
          set -a fd_args --exclude "__pycache__"
          set -a fd_args --exclude ".steam"
          set -a fd_args --exclude ".local/share/Trash"

          set -l file (fd . ''${HOME} $fd_args | fzf --ansi \
            --prompt "File> " \
            --header "CTRL-T: Select a file" \
            --preview-window "right,55%,border-left" \
            --preview "bat --style=numbers --color=always --line-range :500 {}")

          if test -n "$file"
            commandline -i -- "$file"
          end
        end
      '';

      # Custom zoxide directory changer
      fzf_zoxide_changer_corrected = ''
        function fzf_zoxide_changer_corrected
          set -l fd_args --type d --hidden
          set -a fd_args --exclude ".cache"
          set -a fd_args --exclude ".nix-profile"
          set -a fd_args --exclude ".local/state"
          set -a fd_args --exclude ".local/share/Steam"
          set -a fd_args --exclude ".nix-defexpr"
          set -a fd_args --exclude ".git"
          set -a fd_args --exclude "node_modules"
          set -a fd_args --exclude "__pycache__"
          set -a fd_args --exclude ".steam"
          set -a fd_args --exclude ".local/share/Trash"

          set -l dir (
            begin
              zoxide query -l 2>/dev/null
              fd . ''${HOME} $fd_args
            end | awk '!seen[$0]++' | fzf --ansi \
              --prompt "Dir (zoxide first)> " \
              --header "ALT-C: Select a directory (zoxide results first)" \
              --preview-window "right,55%,border-left" \
              --preview "eza --icons --color=always --all --long --header {}")

          if test -n "$dir"
            set -l escaped_dir (string escape -- "$dir")
            set -l command_to_run "cd $escaped_dir; and eza -l --all"
            commandline -r "$command_to_run"
            commandline -f execute
          end
        end
      '';

      # Custom directory insert function
      fzf_insert_dir_corrected = ''
        function fzf_insert_dir_corrected
          set -l fd_args --type d --hidden
          set -a fd_args --exclude ".cache"
          set -a fd_args --exclude ".nix-profile"
          set -a fd_args --exclude ".local/state"
          set -a fd_args --exclude ".nix-defexpr"
          set -a fd_args --exclude ".git"
          set -a fd_args --exclude "node_modules"
          set -a fd_args --exclude "__pycache__"
          set -a fd_args --exclude ".steam"
          set -a fd_args --exclude ".local/share/Trash"

          set -l dir (fd . ''${HOME} $fd_args | fzf --ansi \
            --prompt "Dir> " \
            --header "ALT-D: Select a directory to insert" \
            --preview-window "right,55%,border-left" \
            --preview "eza --icons --color=always --all --long --header {}")

          if test -n "$dir"
            commandline -i -- "$dir"
          end
        end
      '';

      # Custom history widget with tldr preview
      fzf_history_widget_corrected = ''
        function fzf_history_widget_corrected
          set -l selection (history | fzf --ansi --no-sort --tac \
            --height=50% \
            --prompt="History> " \
            --header="CTRL-R: Select command" \
            --preview-window="right,60%,border-left" \
            --preview="fish -c '
              set -l cmd_line \$argv[1];
              echo \$cmd_line | bat --language=fish --color=always --style=grid;
              echo \"---\";
              set -l first_word (string split \" \" -- \$cmd_line)[1];
              tldr \$first_word || echo \"No tldr page for [\$first_word]\"
            ' -- {}"
          )
          if test -n "$selection"
            commandline -r -- "$selection"
          end
        end
      '';
    };
  };
}
