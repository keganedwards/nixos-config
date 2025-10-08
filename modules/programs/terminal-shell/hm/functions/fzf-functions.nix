{
  programs.fish.functions = let
    # Define a common list of directories to exclude for the 'fd' command.
    # This list is then converted into a string of --exclude arguments.
    fdExcludeArgs = builtins.concatStringsSep " " (map (dir: "--exclude \"${dir}\"") [
      ".cache"
      ".nix-profile"
      ".local/state"
      ".nix-defexpr"
      ".git"
      "node_modules"
      "__pycache__"
      ".local/share/Trash" # Corrected capitalization
      ".local/share/Steam" # Corrected path and capitalization
    ]);
  in {
    # Custom file widget function
    fzf_file_widget_corrected = ''
      set -l file (fd . "$HOME" --type f --hidden \
        ${fdExcludeArgs} \
        | fzf --ansi \
          --prompt "File> " \
          --header "CTRL-T: Select a file" \
          --preview-window "right,55%,border-left" \
          --preview "bat --style=numbers --color=always --line-range :500 {}")
      if test -n "$file"
        commandline -i -- "$file"
      end
    '';

    # Custom zoxide directory changer
    fzf_zoxide_changer_corrected = ''
      set -l dir (
        begin
          zoxide query -l 2>/dev/null
          fd . "$HOME" --type d --hidden \
            ${fdExcludeArgs}
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
    '';

    # Custom directory insert function
    fzf_insert_dir_corrected = ''
      set -l dir (fd . "$HOME" --type d --hidden \
        ${fdExcludeArgs} \
        | fzf --ansi \
          --prompt "Dir> " \
          --header "ALT-D: Select a directory to insert" \
          --preview-window "right,55%,border-left" \
          --preview "eza --icons --color=always --all --long --header {}")
      if test -n "$dir"
        commandline -i -- "$dir"
      end
    '';

    # Custom history widget with tldr preview
    fzf_history_widget_corrected = ''
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
    '';
  };
}
