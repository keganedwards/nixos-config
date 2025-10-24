{
  pkgs,
  username,
  ...
}: {
  home-manager.users."protect-${username}" = {
    programs.fish.functions = let
      fdExcludeArgs = builtins.concatStringsSep " " (map (dir: "--exclude \"${dir}\"") [
        ".cache"
        ".nix-profile"
        ".local/state"
        ".nix-defexpr"
        ".git"
        "node_modules"
        "__pycache__"
        ".local/share/Trash"
        ".local/share/Steam"
      ]);
    in {
      fzf_file_widget = ''
        set -l file (${pkgs.fd}/bin/fd . "$HOME" --type f --hidden ${fdExcludeArgs} | \
          ${pkgs.fzf}/bin/fzf --ansi \
            --prompt "File> " \
            --header "CTRL-T: Select a file" \
            --preview-window "right,55%,border-left" \
            --preview "${pkgs.bat}/bin/bat --style=numbers --color=always --line-range :500 {}")
        if test -n "$file"
          commandline -i -- "$file"
        end
      '';

      fzf_zoxide_changer = ''
        set -l dir (
          begin
            ${pkgs.zoxide}/bin/zoxide query -l 2>/null
            ${pkgs.fd}/bin/fd . "$HOME" --type d --hidden ${fdExcludeArgs}
          end | awk '!seen[$0]++' | ${pkgs.fzf}/bin/fzf --ansi \
            --prompt "Dir (zoxide first)> " \
            --header "ALT-C: Select a directory (zoxide results first)" \
            --preview-window "right,55%,border-left" \
            --preview "${pkgs.eza}/bin/eza --icons --color=always --all --long --header {}")

        if test -n "$dir"
          set -l escaped_dir (string escape -- "$dir")
          set -l command_to_run "cd $escaped_dir; and ${pkgs.eza}/bin/eza -l --all"
          commandline -r "$command_to_run"
          commandline -f execute
        end
      '';

      fzf_insert_dir = ''
        set -l dir (${pkgs.fd}/bin/fd . "$HOME" --type d --hidden ${fdExcludeArgs} | \
          ${pkgs.fzf}/bin/fzf --ansi \
            --prompt "Dir> " \
            --header "ALT-D: Select a directory to insert" \
            --preview-window "right,55%,border-left" \
            --preview "${pkgs.eza}/bin/eza --icons --color=always --all --long --header {}")
        if test -n "$dir"
          commandline -i -- "$dir"
        end
      '';

      fzf_history_widget = ''
        set -l selection (history | ${pkgs.fzf}/bin/fzf --ansi --no-sort \
          --height=50% \
          --prompt="History> " \
          --header="CTRL-R: Select command (newest first)" \
          --preview-window="right,60%,border-left" \
          --preview="${pkgs.fish}/bin/fish -c '
            set -l cmd_line \$argv[1];
            echo \$cmd_line | ${pkgs.bat}/bin/bat --language=fish --color=always --style=grid;
            echo \"---\";
            set -l first_word (string split \" \" -- \$cmd_line)[1];
            ${pkgs.tldr}/bin/tldr \$first_word 2>/dev/null || echo \"No tldr page for [\$first_word]\"
          ' -- {}"
        )
        if test -n "$selection"
          commandline -r -- "$selection"
        end
      '';
    };

    programs.fish.interactiveShellInit = ''
      bind \ct 'fzf_file_widget'
      bind \ec 'fzf_zoxide_changer'
      bind \ed 'fzf_insert_dir'
      bind \cr 'fzf_history_widget'
    '';
  };
}
