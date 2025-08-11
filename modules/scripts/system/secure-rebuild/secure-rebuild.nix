# /modules/system/secure-rebuild.nix
{
  pkgs,
  username,
  flakeDir,
  ...
}: {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "secure-rebuild" ''
      #!${pkgs.bash}/bin/bash
      set -e

      if [ "$EUID" -ne 0 ]; then
        echo "Error: This script must be run with sudo"
        exit 1
      fi

      TARGET_COMMIT="''${1:-}"
      if [ -z "$TARGET_COMMIT" ]; then
        echo "Error: No commit hash provided"
        exit 1
      fi
      shift

      if [ $# -eq 0 ]; then
        echo "Error: No rebuild action provided (test, switch, boot, etc.)"
        exit 1
      fi

      # This script trusts that its caller has provided a verified commit hash
      FLAKE_URI="git+file://${flakeDir}?rev=$TARGET_COMMIT"

      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "  Secure NixOS Rebuild"
      echo "  Commit: ''${TARGET_COMMIT:0:7}"
      echo "  Action: $*"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo

      HOSTNAME="''${HOSTNAME:-$(hostname)}"
      ${pkgs.nixos-rebuild}/bin/nixos-rebuild "$@" \
        --flake "$FLAKE_URI#$HOSTNAME"

      echo
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "  ✅ Secure rebuild completed successfully"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    '')
  ];

  security.sudo.extraRules = [
    {
      users = [username];
      commands = [
        {
          command = "/run/current-system/sw/bin/secure-rebuild *";
          options = ["NOPASSWD"];
        }
      ];
    }
  ];
}
