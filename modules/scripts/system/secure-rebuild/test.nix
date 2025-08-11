{
  pkgs,
  username,
  flakeDir,
  ...
}: let
  definitionsDir = "${flakeDir}/modules/home-manager/apps/definitions";
in {
  home-manager.users.${username} = {
    # Enable git delta for better diffs
    programs.git = {
      enable = true;
      delta.enable = true;
    };

    home.packages = [
      (pkgs.writeShellScriptBin "nixos-test" ''
        #!${pkgs.bash}/bin/bash
        set -euo pipefail

        # --- Helper Functions ---
        cd "${flakeDir}"

        notify() {
          ${pkgs.libnotify}/bin/notify-send -u "''${2:-normal}" -a "NixOS Test" "$1" &>/dev/null || true
        }

        reload_sway() {
          if pgrep -x sway >/dev/null; then
            swaymsg reload
          fi
        }

        source_fish() {
          if command -v fish >/dev/null; then
            fish -c "source ~/.config/fish/config.fish"
          fi
        }

        # --- Parse Arguments ---
        force_rebuild=0
        while [[ $# -gt 0 ]]; do
          case $1 in
            -f|--force)
              force_rebuild=1
              shift
              ;;
            -h|--help)
              echo "Usage: nixos-test [-f|--force]"
              echo "  -f, --force    Force rebuild even if repository is clean"
              exit 0
              ;;
            *)
              echo "Unknown option: $1"
              exit 1
              ;;
          esac
        done

        # --- Check for uncommitted changes ---
        made_changes=0
        if ! ${pkgs.git}/bin/git diff --quiet HEAD; then
          echo ":: Uncommitted changes detected."
          echo

          # Show the diff using git delta
          ${pkgs.git}/bin/git diff --color=always | ${pkgs.less}/bin/less -R

          echo
          echo ":: Last commit message:"
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          ${pkgs.git}/bin/git log -1 --pretty=format:"%h - %s%n%n%b"
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo

          # Ask about commit strategy
          read -p "Create new commit? (y/N): " -n 1 -r
          echo

          if [[ $REPLY =~ ^[Yy]$ ]]; then
            # Stage all changes
            ${pkgs.git}/bin/git add .

            # Get commit message
            echo "Enter commit message (or press Ctrl+C to cancel):"
            read -r commit_msg

            if [ -z "$commit_msg" ]; then
              notify "❌ Aborted: Empty commit message" critical
              echo "❌ Aborted: Commit message cannot be empty." >&2
              exit 1
            fi

            ${pkgs.git}/bin/git commit -m "$commit_msg"
          else
            # Amend to previous commit
            echo ":: Amending changes to previous commit..."
            ${pkgs.git}/bin/git add .
            ${pkgs.git}/bin/git commit --amend --no-edit
          fi

          made_changes=1
          echo "✅ Changes committed successfully."
        fi

        # --- Decide whether to build ---
        if [ "$made_changes" -eq 0 ] && [ "$force_rebuild" -eq 0 ]; then
          echo "✅ Repository is clean. No changes to test."
          echo "   Use -f or --force to rebuild anyway."
          exit 0
        fi

        if [ "$made_changes" -eq 1 ]; then
          echo "✅ Changes committed and ready for build."
        else
          echo "✅ Force flag detected. Proceeding with rebuild."
        fi

        # --- Get current commit hash ---
        TARGET_COMMIT=$(${pkgs.git}/bin/git rev-parse HEAD)
        echo ":: Building from commit: ''${TARGET_COMMIT:0:7}"

        # --- Flatpak validation (optional) ---
        if [ -d "${definitionsDir}" ]; then
          echo ":: Validating Flatpak IDs..."
          while IFS= read -r file; do
            id=$(grep -oP 'id\s*=\s*"\K[^"]+' "$file" || true)
            [ -n "$id" ] || continue

            json=$(${pkgs.curl}/bin/curl -sfL "https://flathub.org/api/v1/apps/$id") || {
              notify "❌ Flatpak not found: $id" critical
              exit 1
            }

            canon=$(echo "$json" | ${pkgs.jq}/bin/jq -r .flatpakAppId)
            if [ "$id" != "$canon" ]; then
              notify "❌ Flatpak ID mismatch: '$id' should be '$canon'" critical
              exit 1
            fi
          done < <(grep -l 'type\s*=\s*"flatpak"' -r "${definitionsDir}" 2>/dev/null || true)
          echo "✅ All Flatpak IDs are valid."
        fi

        # --- Build using secure-rebuild ---
        echo ":: Starting NixOS test build..."
        if sudo /run/current-system/sw/bin/secure-rebuild "$TARGET_COMMIT" test; then
          notify "✅ Test build successful!"
          reload_sway
          source_fish
          echo "✅ Test build completed successfully!"
        else
          notify "❌ Test build failed!" critical
          echo "❌ Test build failed!" >&2
          exit 1
        fi
      '')
    ];
    home.shellAliases.nt = "nixos-test";
  };
}
