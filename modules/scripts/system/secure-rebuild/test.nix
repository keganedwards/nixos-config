# /scripts/system/test.nix
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
  nixos-test-wrapper = pkgs.writeShellScriptBin "nixos-test" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    cd "${flakeDir}"

    validate_flatpaks() {
      local added_files="$1"

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
          echo "  -f, --force     Force rebuild even if repository is clean"
          exit 0
          ;;
        *)
          echo "Unknown option: $1"
          exit 1
          ;;
      esac
    done

    # --- Handle force rebuild case ---
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
    if ! ${pkgs.git}/bin/git diff --quiet HEAD; then
      echo ":: Uncommitted changes detected."

      original_head=$(${pkgs.git}/bin/git rev-parse HEAD)

      # Stage and amend atomically (as current user with proper signing)
      ${pkgs.git}/bin/git add .
      ${pkgs.git}/bin/git commit --amend --no-edit --quiet

      TARGET_COMMIT=$(${pkgs.git}/bin/git rev-parse HEAD)

      # Get the diff between the two most recent commits for validation
      added_files=$(${pkgs.git}/bin/git diff --name-only "$original_head" HEAD | ${pkgs.ripgrep}/bin/rg '\.nix$' || true)

      if ! validate_flatpaks "$added_files"; then
        ${pkgs.git}/bin/git reset --hard "$original_head"
        exit 1
      fi

      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "  Starting parallel build and review..."
      echo "  Commit: ''${TARGET_COMMIT:0:7}"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

      # Launch build in separate terminal
      if command -v ${flakeConstants.terminalName} >/dev/null && [ -n "''${WAYLAND_DISPLAY:-}" ]; then
        # Use setsid to detach from parent and prevent shell/fish from interfering
        setsid -f ${flakeConstants.terminalBin} --app-id=nixos-build --title="NixOS Build" \
          ${pkgs.bash}/bin/bash -c "
            echo ':: Authenticating for NixOS test build...'
            if sudo ${nixos-test-build}/bin/nixos-test-build '$TARGET_COMMIT'; then
              ${pkgs.libnotify}/bin/notify-send -u normal -a 'NixOS Test' '✅ Test build successful!'
            else
              ${pkgs.libnotify}/bin/notify-send -u critical -a 'NixOS Test' '❌ Test build failed!'
            fi
            exit
          "
      else
        echo ":: No graphical terminal available, running build in background..."
        (
          sudo ${nixos-test-build}/bin/nixos-test-build "$TARGET_COMMIT"
          if [ $? -eq 0 ]; then
            ${pkgs.libnotify}/bin/notify-send -u normal -a "NixOS Test" "✅ Test build successful!"
          else
            ${pkgs.libnotify}/bin/notify-send -u critical -a "NixOS Test" "❌ Test build failed!"
          fi
        ) &
      fi

      # Review process in CURRENT terminal
      echo
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "  Git Review"
      echo "  (Build window has opened separately)"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo

      echo "Review your changes (press q to exit diff):"
      ${pkgs.git}/bin/git diff --color=always "$original_head" HEAD | ${pkgs.less}/bin/less -R

      echo
      echo ":: Current commit message:"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      ${pkgs.git}/bin/git log -1 --pretty=format:"%s%n%n%b"
      echo
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo

      echo "Choose an option:"
      echo "  1) Keep amended commit as-is"
      echo "  2) Change commit message (will use --no-gpg-sign to avoid re-prompting)"
      echo "  3) Restore original state (undo amend)"
      echo
      read -p "Your choice (1/2/3): " -n 1 -r choice
      echo

      case "$choice" in
        1)
          echo ":: Keeping amended commit..."
          ;;
        2)
          echo ":: Enter new commit message:"
          read -r new_msg
          if [ -n "$new_msg" ]; then
            ${pkgs.git}/bin/git commit --amend -m "$new_msg" --no-gpg-sign --quiet
            echo ":: Commit message updated (note: signature removed to avoid re-authentication)"
            echo ":: You may want to re-sign this commit later with: git commit --amend -S --no-edit"
          else
            echo ":: No message entered, keeping current message"
          fi
          ;;
        3)
          echo ":: Restoring original state..."
          ${pkgs.git}/bin/git reset --hard "$original_head"
          echo ":: Original state restored"
          ;;
        *)
          echo ":: Invalid choice, keeping amended commit..."
          ;;
      esac

      echo
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "  Git review complete!"
      echo "  Build notification will appear when build finishes."
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    else
      echo "✅ Repository is clean. No changes to test."
      echo "   Use -f or --force to rebuild anyway."
      exit 0
    fi
  '';
in {
  programs.nh = {
    enable = true;
  };

  home-manager.users.${username} = {
    programs.git = {
      enable = true;
      delta.enable = true;
    };

    home.packages = [
      nixos-test-build
      nixos-test-wrapper
    ];

    home.shellAliases.nt = "nixos-test";
  };

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
