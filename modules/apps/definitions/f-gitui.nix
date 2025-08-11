# File: modules/home-manager/apps/definitions/f-gitui.nix
{
  pkgs,
  constants,
  ...
}: {
  f-gitui = {
    type = "nix";
    id = "lazygit";
    key = "f";
    desktopFile = {
      generate = true;
      displayName = "Git UI";
      comment = "Terminal UI for git";
      categories = ["Development" "RevisionControl"];
    };
    launchScript = {
      path = ./_shared/general-multiplexer-launcher-script.nix;
      args = {
        appId = "${constants.terminalName}-gitui";
        sessionName = "gitui";
        terminalBin = constants.terminalBin;
        commandToRun = "${pkgs.lazygit}/bin/lazygit";
        commandArgs = "";
        tabNameStrategy = "custom";
        customTabNameCmd = ''
          # Get git repo name or directory name
          if git rev-parse --show-toplevel >/dev/null 2>&1; then
            echo "$($BASENAME_BIN "$(git rev-parse --show-toplevel)")"
          else
            echo "$($BASENAME_BIN "$(pwd)")"
          fi
        '';
        deduplicationStrategy = "custom";
        customDeduplicationCmd = ''
          # Check if a tab exists for this git repo
          local search_dir="$1"
          if [ -n "$search_dir" ] && [ -d "$search_dir" ]; then
            cd "$search_dir"
          fi

          local target_repo=""
          if git rev-parse --show-toplevel >/dev/null 2>&1; then
            target_repo="$(git rev-parse --show-toplevel)"
          fi

          if [ -z "$target_repo" ]; then
            echo ""
            return
          fi

          # Check each tmux window's current path
          $MULTIPLEXER_BIN list-windows -t "$SESSION_NAME" -F "#{window_index}:#{pane_current_path}" 2>/dev/null | \
            while IFS=: read -r idx path; do
              if [ -d "$path" ]; then
                cd "$path" 2>/dev/null || continue
                if git rev-parse --show-toplevel >/dev/null 2>&1; then
                  if [ "$(git rev-parse --show-toplevel)" = "$target_repo" ]; then
                    echo "$idx"
                    return
                  fi
                fi
              fi
            done
        '';
      };
    };
  };

  # Enable lazygit
  programs.lazygit = {
    enable = true;
  };
}
