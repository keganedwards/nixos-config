{
  pkgs,
  username,
  flakeDir,
  terminalConstants,
  terminalShellConstants,
  ...
}: let
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

    /run/current-system/sw/bin/secure-rebuild "$TARGET_COMMIT" test --ask
    BUILD_RESULT=$?

    if [ $BUILD_RESULT -eq 0 ]; then
      echo
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "  Post-build actions..."
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

      if command -v ${terminalShellConstants.name} >/dev/null 2>&1; then
        echo -n "  Reloading ${terminalShellConstants.name} configuration... "
        runuser -u ${username} -- ${terminalShellConstants.reloadCommand} >/dev/null 2>&1 || true
        echo "done"
      fi

      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo
    fi

    exit $BUILD_RESULT
  '';

  nixos-test-wrapper = pkgs.writeShellScriptBin "nt" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    cd "${flakeDir}"

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

    if [ "$force_rebuild" -eq 1 ]; then
      TARGET_COMMIT=$(${pkgs.git}/bin/git rev-parse HEAD)
      echo "✅ Force flag detected. Proceeding with rebuild."
      echo ":: Building from commit: ''${TARGET_COMMIT:0:7}"
      echo ":: Authenticating for NixOS test build..."

      if exec sudo ${nixos-test-build}/bin/nixos-test-build "$TARGET_COMMIT"; then
        ${pkgs.libnotify}/bin/notify-send -u normal -a "NixOS Test" "✅ Test build successful!"
        exit 0
      else
        ${pkgs.libnotify}/bin/notify-send -u critical -a "NixOS Test" "❌ Test build failed!"
        exit 1
      fi
    fi

    if ! ${pkgs.git}/bin/git diff --quiet HEAD || [ -n "$(${pkgs.git}/bin/git ls-files --others --exclude-standard)" ]; then
      echo ":: Uncommitted changes detected."

      original_head=$(${pkgs.git}/bin/git rev-parse HEAD)

      ${pkgs.git}/bin/git add .

      if ! ${pkgs.git}/bin/git diff --quiet --staged; then
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "  Commit message (empty to amend):"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        IFS= read -r commit_msg

        if [ -z "$commit_msg" ]; then
          ${pkgs.git}/bin/git commit --amend --no-edit --quiet
          echo ":: Amended last commit"
        else
          ${pkgs.git}/bin/git commit -m "$commit_msg" --quiet
          echo ":: Created new commit"
        fi

        TARGET_COMMIT=$(${pkgs.git}/bin/git rev-parse HEAD)
      else
        echo ":: No changes to commit (all changes were already staged)"
        TARGET_COMMIT="$original_head"
      fi

      if [ "$TARGET_COMMIT" != "$original_head" ]; then
        if command -v ${terminalConstants.name} >/dev/null && [ -n "''${WAYLAND_DISPLAY:-}" ]; then
          setsid -f ${terminalConstants.bin} start --class nixos-diff \
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

      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ":: Starting NixOS test build for commit: ''${TARGET_COMMIT:0:7}"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo

      exec sudo ${nixos-test-build}/bin/nixos-test-build "$TARGET_COMMIT"

    else
      echo "✅ Repository is clean. No changes to test."
      echo "    Use -f or --force to rebuild anyway."
      exit 0
    fi
  '';

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

  secure-rebuild = pkgs.writeShellScriptBin "secure-rebuild" ''
    #!${pkgs.bash}/bin/bash
    set -e

    if [ "$EUID" -ne 0 ]; then
      echo "Error: This script must be run as root"
      echo "Usage: sudo secure-rebuild <commit-hash> <action> [additional-args...]"
      exit 1
    fi

    TARGET_COMMIT="''${1:-}"
    if [ -z "$TARGET_COMMIT" ]; then
      echo "Error: No commit hash provided"
      exit 1
    fi
    shift

    ACTION="''${1:-}"
    if [ -z "$ACTION" ]; then
      echo "Error: No rebuild action provided (test, switch, boot, etc.)"
      exit 1
    fi
    shift

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Performing comprehensive commit verification..."
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    cd "${flakeDir}"

    CURRENT_COMMIT=""
    if [ -f /run/current-system/nixos-version ]; then
      CURRENT_COMMIT=$(${pkgs.ripgrep}/bin/rg -oP '[a-f0-9]{40}' /run/current-system/nixos-version | head -1 || echo "")
    fi

    if [ -z "$CURRENT_COMMIT" ]; then
      echo "⚠ Cannot determine current system commit, finding last verified commit..."
      COMMITS=$(runuser -u ${username} -- ${pkgs.git}/bin/git rev-list HEAD --reverse)
      LAST_VERIFIED=""
      for commit in $COMMITS; do
        if runuser -u ${username} -- ${pkgs.git}/bin/git verify-commit "$commit" 2>/dev/null; then
          LAST_VERIFIED="$commit"
        else
          break
        fi
      done
      if [ -z "$LAST_VERIFIED" ]; then
        echo "❌ SECURITY ERROR: No verified commits found in history!"
        exit 1
      fi
      CURRENT_COMMIT="$LAST_VERIFIED"
      echo "  Using last verified commit as baseline: ''${CURRENT_COMMIT:0:7}"
    else
      echo "  Current system commit: ''${CURRENT_COMMIT:0:7}"
    fi

    echo ""
    echo "  Verifying all commits from ''${CURRENT_COMMIT:0:7} to ''${TARGET_COMMIT:0:7}..."
    echo ""
    COMMITS_TO_VERIFY=$(runuser -u ${username} -- ${pkgs.git}/bin/git rev-list --reverse "$CURRENT_COMMIT..$TARGET_COMMIT")
    if ! echo "$COMMITS_TO_VERIFY" | ${pkgs.ripgrep}/bin/rg -q "$TARGET_COMMIT"; then
      COMMITS_TO_VERIFY=$(echo -e "''${COMMITS_TO_VERIFY}\n$TARGET_COMMIT" | ${pkgs.ripgrep}/bin/rg -v '^$')
    fi
    VERIFIED_COUNT=0
    FAILED_COMMITS=()
    for commit in $COMMITS_TO_VERIFY; do
      COMMIT_SHORT="''${commit:0:7}"
      COMMIT_SUBJECT=$(runuser -u ${username} -- ${pkgs.git}/bin/git log --format=%s -n 1 "$commit")
      COMMIT_AUTHOR=$(runuser -u ${username} -- ${pkgs.git}/bin/git log --format="%an <%ae>" -n 1 "$commit")
      echo -n "  Checking $COMMIT_SHORT: $COMMIT_SUBJECT (by $COMMIT_AUTHOR)... "
      if runuser -u ${username} -- ${pkgs.git}/bin/git verify-commit "$commit" 2>/dev/null; then
        echo "✅"
        VERIFIED_COUNT=$((VERIFIED_COUNT + 1))
      else
        echo "❌ UNSIGNED"
        FAILED_COMMITS+=("$commit|$COMMIT_SUBJECT|$COMMIT_AUTHOR")
      fi
    done
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    if [ ''${#FAILED_COMMITS[@]} -gt 0 ]; then
      echo "❌ SECURITY ERROR: Found ''${#FAILED_COMMITS[@]} unsigned/unverified commit(s)!"
      echo ""
      echo "The following commits failed verification:"
      for failed in "''${FAILED_COMMITS[@]}"; do
        IFS='|' read -r hash subject author <<< "$failed"
        echo "  • ''${hash:0:7}: $subject (by $author)"
      done
      echo ""
      echo "This could indicate:"
      echo "  1. Commits made without proper signing"
      echo "  2. Commits signed with an untrusted key"
      echo "  3. Potential tampering or unauthorized changes"
      echo ""
      echo "❌ BUILD ABORTED FOR SECURITY REASONS"
      exit 1
    fi
    echo "✅ Successfully verified $VERIFIED_COUNT commit(s)"
    echo "  All commits in range are properly signed and trusted"
    echo ""
    FLAKE_URI="git+file://${flakeDir}?rev=$TARGET_COMMIT"
    HOSTNAME="''${HOSTNAME:-$(hostname)}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Secure NixOS Rebuild (using nh)"
    echo "  Commit Range: ''${CURRENT_COMMIT:0:7}..''${TARGET_COMMIT:0:7}"
    echo "  Action: $ACTION"
    echo "  Host: $HOSTNAME"
    echo "  Flake: $FLAKE_URI"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo

    NH_FLAGS=(-v)
    NIX_FLAGS=()
    for arg in "$@"; do
      case "$arg" in
        --ask|-a|--dry|-n|--no-nom|--update|-u|--no-specialisation|-S)
          NH_FLAGS+=("$arg")
          ;;
        --verbose|-v)
          ;;
        --update-input|-U|--hostname|-H|--specialisation|-s|--out-link|-o|--target-host|--build-host)
          NH_FLAGS+=("$arg")
          if [[ $# -gt 0 ]]; then
            shift
            NH_FLAGS+=("$1")
          fi
          ;;
        *)
          NIX_FLAGS+=("$arg")
          ;;
      esac
    done

    if [ ''${#NIX_FLAGS[@]} -gt 0 ]; then
      ${pkgs.nh}/bin/nh os "$ACTION" "$FLAKE_URI" -H "$HOSTNAME" -R "''${NH_FLAGS[@]}" -- "''${NIX_FLAGS[@]}"
    else
      ${pkgs.nh}/bin/nh os "$ACTION" "$FLAKE_URI" -H "$HOSTNAME" -R "''${NH_FLAGS[@]}"
    fi

    echo
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  ✅ Secure rebuild completed successfully"
    echo "  Verified and built from commit: ''${TARGET_COMMIT:0:7}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  '';
in {
  programs.nh = {
    enable = true;
  };

  environment.systemPackages = with pkgs; [
    nixos-test-build
    nt-wrapper
    secure-rebuild
    ripgrep
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
