{
  pkgs,
  flakeDir,
  username,
  ...
}:
assert flakeDir != null; {
  home-manager.users.${username} = {
    home = {
      shellAliases.np = "nixos-push";
      packages = with pkgs; [
        git
        nixos-rebuild
        libnotify

        (writeShellScriptBin "nixos-push" ''
          #!${pkgs.runtimeShell}
          set -euo pipefail

          WORKSPACE="${flakeDir}"
          BRANCH="main"
          REMOTE="origin"
          FORCE_OPTS=""

          NOTIFY(){ notify-send -u "''${2:-normal}" -a "NixOS Push" "$1" &>/dev/null || true; }

          while [ "$#" -gt 0 ]; do
            case "$1" in
              -f|--force) FORCE_OPTS="--force"; shift ;;
              -h|--help)  echo "Usage: nixos-push [-f|--force]"; exit 0 ;;
              *)          echo "Unknown option: $1" >&2; exit 1 ;;
            esac
          done

          cd "$WORKSPACE"

          if ! git diff --quiet HEAD; then
            NOTIFY "❌ Push Aborted: Uncommitted changes" critical
            echo "❌ Aborting: uncommitted changes exist." >&2
            exit 1
          fi

          git fetch "$REMOTE"

          LOCAL_COMMITS=$(git rev-list --count "$REMOTE/$BRANCH..HEAD" 2>/dev/null || echo 0)
          if [ "$LOCAL_COMMITS" = "0" ]; then
            NOTIFY "Push Skipped: No commits to push"
            echo "✅ Repository is up-to-date."
          else
            git push $FORCE_OPTS "$REMOTE" "$BRANCH" \
              && NOTIFY "✅ Git push successful" \
              || { NOTIFY "❌ Git push failed" critical; exit 1; }
          fi

          if [ -L /run/current-system ]; then
            CUR=$(readlink -f /run/current-system)
            LATEST=$(readlink -f /nix/var/nix/profiles/system)
            if [ "$CUR" != "$LATEST" ]; then
              SWITCH="$LATEST/bin/switch-to-configuration"
              if [ -x "$SWITCH" ]; then
                sudo "$SWITCH" switch \
                  && NOTIFY "✅ System switched to new generation" \
                  || { NOTIFY "❌ Activation failed" critical; exit $?; }
              else
                NOTIFY "❌ Activation script missing" critical
                exit 1
              fi
            else
              echo "✅ Already on latest generation."
            fi
          fi
        '')
      ];
    };
  };
}
