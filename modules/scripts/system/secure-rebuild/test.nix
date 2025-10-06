{
  pkgs,
  username,
  flakeDir,
  config,
  ...
}: let
  definitionsDir = "${flakeDir}/modules/home-manager/apps/definitions";

  # Define the implementation script that runs WITH sudo
  nixos-test-build = pkgs.writeShellScriptBin "nixos-test-build" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    TARGET_COMMIT="$1"

    cd "${flakeDir}"

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  NixOS Test Build"
    echo "  Commit: ''${TARGET_COMMIT:0:7}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo
    echo "The build will show a comparison and ask for"
    echo "confirmation. Type 'y' or 'yes' to proceed."
    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    # Run the build and capture result
    /run/current-system/sw/bin/secure-rebuild "$TARGET_COMMIT" test --ask
    BUILD_RESULT=$?

    # Post-build actions only on success
    if [ $BUILD_RESULT -eq 0 ]; then
      echo
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "  Post-build actions..."
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

      # Reload sway if running
      if pgrep -x sway >/dev/null 2>&1; then
        echo -n "  Reloading Sway configuration... "
        runuser -u ${username} -- swaymsg reload >/dev/null 2>&1 || true
        echo "done"
      fi

      # Source fish config if available
      if command -v fish >/dev/null 2>&1; then
        echo -n "  Sourcing Fish configuration... "
        runuser -u ${username} -- fish -c "source ~/.config/fish/config.fish" >/dev/null 2>&1 || true
        echo "done"
      fi

      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo
    fi

    # Explicitly exit with the build result
    exit $BUILD_RESULT
  '';

  # Main script that runs WITHOUT sudo initially
  nixos-test-wrapper = pkgs.writeShellScriptBin "nt" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    cd "${flakeDir}"

    validate_flatpaks() {
      added_files="$1"

      if [ -z "$added_files" ] || [ ! -d "${definitionsDir}" ]; then
        return 0
      fi

      echo ":: Validating Flatpak IDs in new/modified files..."

      while IFS= read -r file; do
        # Skip if file is not in definitions directory
        if [[ ! "$file" =~ ^modules/home-manager/apps/definitions/ ]]; then
          continue
        fi

        # Check if it's a flatpak definition
        if ! ${pkgs.ripgrep}/bin/rg -q 'type\s*=\s*"flatpak"' "$file" 2>/dev/null; then
          continue
        fi

        id=$(${pkgs.ripgrep}/bin/rg -o 'id\s*=\s*"([^"]+)"' -r '$1' "$file" || true)
        [ -n "$id" ] || continue

        json=$(${pkgs.curl}/bin/curl -sfL "https://flathub.org/api/v1/apps/$id") || {
          echo "❌ Flatpak not found: $id (in $file)" >&2
          return 1
        }

        canon=$(echo "$json" | ${pkgs.jq}/bin/jq -r .flatpakAppId)
        if [ "$id" != "$canon" ]; then
          echo "❌ Flatpak ID mismatch in $file: '$id' should be '$canon'" >&2
          return 1
        fi
      done <<< "$added_files"

      echo "✅ All Flatpak IDs are valid."
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
          echo "  -f, --force      Force rebuild even if repository is clean"
          exit 0
          ;;
        *)
          echo "Unknown option: $1"
          exit 1
          ;;
      esac
    done

    # --- Handle force rebuild case (no review required) ---
    if [ "$force_rebuild" -eq 1 ]; then
      TARGET_COMMIT=$(${pkgs.git}/bin/git rev-parse HEAD)
      echo "✅ Force flag detected. Proceeding with rebuild."
      echo ":: Building from commit: ''${TARGET_COMMIT:0:7}"

      # Get files changed in the last commit for validation
      added_files=$(${pkgs.git}/bin/git diff-tree --no-commit-id --name-only -r HEAD | ${pkgs.ripgrep}/bin/rg '\.nix$' || true)

      if ! validate_flatpaks "$added_files"; then
        exit 1
      fi

      echo ":: Authenticating for NixOS test build..."

      # Run build directly and handle result
      if exec sudo ${nixos-test-build}/bin/nixos-test-build "$TARGET_COMMIT"; then
        ${pkgs.libnotify}/bin/notify-send -u normal -a "NixOS Test" "✅ Test build successful!"
        exit 0
      else
        ${pkgs.libnotify}/bin/notify-send -u critical -a "NixOS Test" "❌ Test build failed!"
        exit 1
      fi
    fi

    # --- Check for uncommitted changes ---
    if ! ${pkgs.git}/bin/git diff --quiet HEAD || [ -n "$(${pkgs.git}/bin/git ls-files --others --exclude-standard)" ]; then
      echo ":: Uncommitted changes detected."

      original_head=$(${pkgs.git}/bin/git rev-parse HEAD)

      # Collect all changed .nix files (unstaged, staged, untracked)
      added_files=$(
        {
          ${pkgs.git}/bin/git diff --name-only HEAD || true
          ${pkgs.git}/bin/git diff --name-only --staged || true
          ${pkgs.git}/bin/git ls-files --others --exclude-standard || true
        } | ${pkgs.ripgrep}/bin/rg '\.nix$' || true
      )

      if ! validate_flatpaks "$added_files"; then
        exit 1
      fi

      # Stage all changes
      ${pkgs.git}/bin/git add .

      # Check if there are staged changes to commit
      if ! ${pkgs.git}/bin/git diff --quiet --staged; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Commit message (empty to amend):"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        IFS= read -r commit_msg
        
        if [ -z "$commit_msg" ]; then
          # Empty message = amend
          ${pkgs.git}/bin/git commit --amend --no-edit --quiet
          echo ":: Amended last commit"
        else
          # Non-empty message = new commit
          ${pkgs.git}/bin/git commit -m "$commit_msg" --quiet
          echo ":: Created new commit"
        fi

        TARGET_COMMIT=$(${pkgs.git}/bin/git rev-parse HEAD)
      else
        echo ":: No changes to commit (all changes were already staged)"
        TARGET_COMMIT="$original_head"
      fi

      # Spawn diff window if possible and there were actual changes
      if [ "$TARGET_COMMIT" != "$original_head" ]; then
        if command -v ${config.terminalConstants.name} >/dev/null && [ -n "''${WAYLAND_DISPLAY:-}" ]; then
          # Simple diff viewing without complex signaling
          setsid -f ${config.terminalConstants.launchWithAppId "nixos-diff"} -- --title="NixOS Diff Review" \
            ${pkgs.bash}/bin/bash -c "
              cd '${flakeDir}'
              echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
              echo '  Git Diff Review'
              echo '  Commit: ''${TARGET_COMMIT:0:7}'
              echo '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━'
              echo
              echo 'Review your changes (press q to exit diff):'
              ${pkgs.git}/bin/git diff --color=always '$original_head' '$TARGET_COMMIT' | ${pkgs.less}/bin/less -R
            " &

          echo ":: Diff review terminal launched."
        else
          echo ":: No graphical terminal available — showing diff here before build."
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo "  Git Diff Review"
          echo "  Commit: ''${TARGET_COMMIT:0:7}"
          echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
          echo
          echo "Review your changes (press q to exit diff):"
          ${pkgs.git}/bin/git diff --color=always "$original_head" "$TARGET_COMMIT" | ${pkgs.less}/bin/less -R
        fi
      fi

      # Start build in this window
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ":: Starting NixOS test build for commit: ''${TARGET_COMMIT:0:7}"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo

      # Use exec to replace the current shell with sudo
      exec sudo ${nixos-test-build}/bin/nixos-test-build "$TARGET_COMMIT"
      # Notification will be sent by wrapper on exit

    else
      echo "✅ Repository is clean. No changes to test."
      echo "    Use -f or --force to rebuild anyway."
      exit 0
    fi
  '';

  # Create a simple wrapper to handle notifications after the main script exits
  nt-wrapper = pkgs.writeShellScriptBin "nt" ''
    #!${pkgs.bash}/bin/bash
    ${nixos-test-wrapper}/bin/nt "$@"
    RESULT=$?
    if [ $RESULT -eq 0 ]; then
      ${pkgs.libnotify}/bin/notify-send -u normal -a "NixOS Test" "✅ Test build successful!" 2>/dev/null || true
    else
      ${pkgs.libnotify}/bin/notify-send -u critical -a "NixOS Test" "❌ Test build failed!" 2>/dev/null || true
    fi
    exit $RESULT
  '';
in {
  programs.nh = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    nixos-test-build
    nt-wrapper
  ];

  security.sudo-rs.extraRules = [
    {
      users = [username];
      commands = [
        {
          command = "${nixos-test-build}/bin/nixos-test-build";
          options = ["NOPASSWD"];
        }
        {
          command = "${nixos-test-build}/bin/nixos-test-build *";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];
}
