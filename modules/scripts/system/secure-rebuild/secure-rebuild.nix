# /modules/system/secure-rebuild.nix
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

      # SECURITY: Verify commit signature before proceeding
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "  Verifying commit signature..."
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

      cd "${flakeDir}"

      # Simple signature verification using git verify-commit
      # This relies on the allowed_signers file already configured by git.nix
      if ! runuser -u ${username} -- ${pkgs.git}/bin/git verify-commit "$TARGET_COMMIT" 2>/dev/null; then
        echo "❌ SECURITY ERROR: Commit $TARGET_COMMIT signature verification failed!"
        echo "This commit is either unsigned or signed with an untrusted key."
        exit 1
      fi

      echo "✅ Commit signature verified against allowed signers"
      echo

      # Build the flake URI without hostname
      FLAKE_URI="git+file://${flakeDir}?rev=$TARGET_COMMIT"
      HOSTNAME="''${HOSTNAME:-$(hostname)}"

      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "  Secure NixOS Rebuild (using nh)"
      echo "  Commit: ''${TARGET_COMMIT:0:7}"
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
