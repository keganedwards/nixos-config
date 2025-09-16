{
  pkgs,
  username,
  flakeDir,
  ...
}: {
  # Enable nh for improved NixOS rebuild UX
  programs.nh = {
    enable = true;
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "secure-rebuild" ''
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

      # SECURITY: Verify ALL commits from the last known-good commit to the target
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "  Performing comprehensive commit verification..."
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

      cd "${flakeDir}"

      # Find the last known-good commit (the one currently deployed)
      CURRENT_COMMIT=""
      if [ -f /run/current-system/nixos-version ]; then
        # Try to extract commit hash from nixos-version if it contains it
        CURRENT_COMMIT=$(grep -oP '[a-f0-9]{40}' /run/current-system/nixos-version | head -1 || echo "")
      fi

      # If we can't determine the current commit, find the last verified commit
      if [ -z "$CURRENT_COMMIT" ]; then
        echo "⚠ Cannot determine current system commit, finding last verified commit..."

        # Get all commits and find the most recent verified one
        COMMITS=$(runuser -u ${username} -- ${pkgs.git}/bin/git rev-list HEAD --reverse)
        LAST_VERIFIED=""

        for commit in $COMMITS; do
          if runuser -u ${username} -- ${pkgs.git}/bin/git verify-commit "$commit" 2>/dev/null; then
            LAST_VERIFIED="$commit"
          else
            break  # Stop at first unverified commit
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

      # Get all commits between current and target (inclusive of target)
      echo ""
      echo "  Verifying all commits from ''${CURRENT_COMMIT:0:7} to ''${TARGET_COMMIT:0:7}..."
      echo ""

      # Get list of commits to verify (from oldest to newest)
      COMMITS_TO_VERIFY=$(runuser -u ${username} -- ${pkgs.git}/bin/git rev-list --reverse "$CURRENT_COMMIT..$TARGET_COMMIT")

      # Add the target commit itself if it's not already included
      if ! echo "$COMMITS_TO_VERIFY" | grep -q "$TARGET_COMMIT"; then
        COMMITS_TO_VERIFY=$(echo -e "''${COMMITS_TO_VERIFY}\n$TARGET_COMMIT" | grep -v '^$')
      fi

      # Verify each commit in the range
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

      # Check if all commits were verified
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

      # Build the flake URI without hostname
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

      # Parse nh flags vs nix flags
      NH_FLAGS=()
      NIX_FLAGS=()

      for arg in "$@"; do
        case "$arg" in
          --ask|-a|--dry|-n|--verbose|-v|--no-nom|--update|-u|--no-specialisation|-S)
            # These are nh flags
            NH_FLAGS+=("$arg")
            ;;
          --update-input|-U|--hostname|-H|--specialisation|-s|--out-link|-o|--target-host|--build-host)
            # These nh flags take values, so add both the flag and next arg
            NH_FLAGS+=("$arg")
            if [[ $# -gt 0 ]]; then
              shift
              NH_FLAGS+=("$1")
            fi
            ;;
          *)
            # Everything else goes to nix
            NIX_FLAGS+=("$arg")
            ;;
        esac
      done

      # nh syntax: nh os <action> <installable> [nh-flags] [-- nix-flags]
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
    '')
  ];

  # More specific NOPASSWD rule to ensure it matches exactly
  security.sudo-rs.extraRules = [
    {
      users = [username];
      commands = [
        {
          command = "/run/current-system/sw/bin/secure-rebuild";
          options = ["NOPASSWD"];
        }
        {
          command = "/run/current-system/sw/bin/secure-rebuild *";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];
}
