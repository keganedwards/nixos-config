{
  pkgs,
  username,
  flakeDir,
  flakeConstants,
  ...
}: let
  definitionsDir = "${flakeDir}/modules/home-manager/apps/definitions";

  # Define the implementation script that runs WITH sudo
  nixos-test-build = pkgs.writeShellScriptBin "nixos-test-build" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    TARGET_COMMIT="$1"

    cd "${flakeDir}"

    reload_sway() {
      if pgrep -x sway >/dev/null; then
        runuser -u ${username} -- swaymsg reload &>/dev/null || true
      fi
    }

    source_fish() {
      if command -v fish >/dev/null; then
        runuser -u ${username} -- fish -c "source ~/.config/fish/config.fish" &>/dev/null || true
      fi
    }

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

    # Run the build and capture its exit code immediately
    /run/current-system/sw/bin/secure-rebuild "$TARGET_COMMIT" test --ask
    BUILD_RESULT=$?

    # Handle post-build actions
    if [ $BUILD_RESULT -eq 0 ]; then
      reload_sway
      source_fish
      exit 0
    else
      exit 1
    fi
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
      if sudo ${nixos-test-build}/bin/nixos-test-build "$TARGET_COMMIT"; then
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
        # Commit menu
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Commit Changes"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo
        echo ":: Current commit message:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        ${pkgs.git}/bin/git log -1 --pretty=format:"%s%n%n%b" HEAD
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo
        echo ":: Changes have been staged. Choose how to proceed:"
        echo
        echo "  (a) Amend the last commit (preserves existing message)"
        echo "  (c) Create new commit with message"
        echo "  (m) Amend the last commit with new message"
        echo "  (q) Quit and restore original state"
        echo
        printf "Your choice (a/c/m/q): "
        IFS= read -r choice
        echo

        case "$choice" in
          a|A)
            # Amend without changing the message
            ${pkgs.git}/bin/git commit --amend --no-edit --quiet
            echo ":: Commit amended (message preserved)"
            ;;
          c|C)
            echo ":: Enter commit message:"
            IFS= read -r commit_msg
            if [ -n "$commit_msg" ]; then
              ${pkgs.git}/bin/git commit -m "$commit_msg" --quiet
            else
              echo ":: No message entered, using automatic message"
              ${pkgs.git}/bin/git commit -m "nixos: test build changes" --quiet
            fi
            ;;
          m|M)
            echo ":: Enter new commit message for amend:"
            IFS= read -r new_msg
            if [ -n "$new_msg" ]; then
              ${pkgs.git}/bin/git commit --amend -m "$new_msg" --no-gpg-sign --quiet
              echo ":: Commit amended with new message (note: signature removed to avoid re-authentication)"
              echo ":: You may want to re-sign this commit later with: git commit --amend -S --no-edit"
            else
              echo ":: No message entered, keeping original message"
              ${pkgs.git}/bin/git commit --amend --no-edit --quiet
            fi
            ;;
          q|Q)
            echo ":: Restoring original state and aborting build..."
            ${pkgs.git}/bin/git reset --hard "$original_head"
            echo ":: Original state restored"
            exit 1
            ;;
          *)
            echo ":: Invalid choice, amending without changing message..."
            ${pkgs.git}/bin/git commit --amend --no-edit --quiet
            ;;
        esac

        TARGET_COMMIT=$(${pkgs.git}/bin/git rev-parse HEAD)
      else
        echo ":: No changes to commit (all changes were already staged)"
        TARGET_COMMIT="$original_head"
      fi

      # Spawn diff window if possible and there were actual changes
      if [ "$TARGET_COMMIT" != "$original_head" ]; then
        if command -v ${flakeConstants.terminalName} >/dev/null && [ -n "''${WAYLAND_DISPLAY:-}" ]; then
          # Create a named pipe for build completion signaling
          build_signal_pipe="/tmp/nixos-build-signal-$"
          mkfifo "$build_signal_pipe"

          # Cleanup function
          cleanup() {
            rm -f "$build_signal_pipe" 2>/dev/null || true
          }
          trap cleanup EXIT

          diff_script='
            set -euo pipefail
            cd "'"${flakeDir}"'"

            original_head="'"$original_head"'"
            TARGET_COMMIT="'"$TARGET_COMMIT"'"
            build_signal_pipe="'"$build_signal_pipe"'"

            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo "  Git Diff Review"
            echo "  Commit: ''${TARGET_COMMIT:0:7}"
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
            echo
            echo "Review your changes (press q to exit diff):"

            # Start the diff in background so we can monitor for build completion
            '"${pkgs.git}"'/bin/git diff --color=always "$original_head" "$TARGET_COMMIT" | '"${pkgs.less}"'/bin/less -R &
            LESS_PID=$!

            # Start monitoring for build signal
            (
              # Wait for signal from main process
              read build_status < "$build_signal_pipe"
              # Kill less when we get the signal
              kill $LESS_PID 2>/dev/null || true
              wait $LESS_PID 2>/dev/null || true
              clear
              echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
              echo "  Build completed: $build_status"
              echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
              sleep 2
              exit 0
            ) &
            MONITOR_PID=$!

            # Wait for either less to exit or monitor to signal completion
            wait $LESS_PID 2>/dev/null || true
            kill $MONITOR_PID 2>/dev/null || true
            exit 0
          '

          setsid -f ${flakeConstants.terminalBin} --app-id=nixos-diff --title="NixOS Diff Review" \
            ${pkgs.bash}/bin/bash -lc "$diff_script" &
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

      if sudo ${nixos-test-build}/bin/nixos-test-build "$TARGET_COMMIT"; then
        ${pkgs.libnotify}/bin/notify-send -u normal -a "NixOS Test" "✅ Test build successful!"
        # Signal completion to diff window
        echo "success" > "$build_signal_pipe" 2>/dev/null || true
        exit 0
      else
        ${pkgs.libnotify}/bin/notify-send -u critical -a "NixOS Test" "❌ Test build failed!"
        # Signal completion to diff window
        echo "failed" > "$build_signal_pipe" 2>/dev/null || true
        exit 1
      fi

    else
      echo "✅ Repository is clean. No changes to test."
      echo "    Use -f or --force to rebuild anyway."
      exit 0
    fi
  '';
in {
  programs.nh = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    nixos-test-build
    nixos-test-wrapper
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
