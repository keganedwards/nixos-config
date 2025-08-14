# modules/home-manager/scripts/vpn-app-launcher.nix
{
  pkgs,
  config,
  lib,
  ...
}: let
  vpnApps = lib.filterAttrs (
    _name: app:
      (app.vpn or {}).enabled or false
  ) (config.applications or {});

  launchScript = pkgs.writeShellScriptBin "launch-vpn-app" ''
    #!/usr/bin/env bash

    APP_NAME="$1"
    shift

    # Function to sanitize service names
    sanitize() {
      echo "$1" | tr -cd '[:alnum:]-_' | tr '[:upper:]' '[:lower:]'
    }

    case "$APP_NAME" in
      ${lib.concatStringsSep "\n" (lib.mapAttrsToList (name: _app: ''
        ${name})
          SERVICE_NAME="vpn-app-$(sanitize "${name}")"
          echo "Starting $SERVICE_NAME..."
          sudo systemctl start "$SERVICE_NAME.service"
          ;;
      '')
      vpnApps)}
      *)
        echo "Unknown VPN app: $APP_NAME"
        echo "Available VPN apps: ${lib.concatStringsSep ", " (lib.attrNames vpnApps)}"
        exit 1
        ;;
    esac
  '';
in {
  home.packages = [launchScript];
}
