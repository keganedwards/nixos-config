# modules/home-manager/vpn-apps.nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.vpn-apps;

  vpnAppOptions = {
    name,
    ...
  }: {
    options = {
      name = mkOption {
        type = types.str;
        description = "Name of the application to run through VPN";
      };

      command = mkOption {
        type = types.str;
        description = "Command to run the application";
      };

      flatpakId = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Flatpak ID if this is a flatpak app";
      };

      args = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Additional arguments for the command";
      };
    };
  };
in {
  options.services.vpn-apps = {
    enable = mkEnableOption "VPN apps service";

    namespace = mkOption {
      type = types.str;
      default = "vo_pr_us";
      description = "VPN namespace to use";
    };

    apps = mkOption {
      type = types.listOf (types.submodule vpnAppOptions);
      default = [];
      description = "List of applications to run through VPN";
    };
  };

  config = mkIf cfg.enable {
    home.packages = [
      (pkgs.writeShellScriptBin "run-vpn-app" ''
        #!${pkgs.bash}/bin/bash
        set -eu

        NAMESPACE="${cfg.namespace}"

        # Check if namespace exists
        if ! ${pkgs.iproute2}/bin/ip netns list 2>/dev/null | grep -q "^$NAMESPACE"; then
          echo "Error: VPN namespace $NAMESPACE not found."
          echo "The VPN service may not be running."
          echo "Try: sudo systemctl start vpn-namespace.service"
          exit 1
        fi

        # Check service status
        if ! systemctl is-active --quiet vpn-namespace.service; then
          echo "Warning: VPN service is not active"
          echo "Starting service..."
          sudo systemctl start vpn-namespace.service
          echo "Waiting for namespace to be ready..."
          sleep 5
        fi

        # Get the application ID
        if [ "$#" -lt 1 ]; then
          echo "Error: No application specified."
          echo "Usage: $(basename "$0") <app-id> [arguments...]"
          exit 1
        fi

        APP_ID="$1"
        shift

        # Run the specified app through the VPN namespace
        exec sudo -u vpnrunner ${pkgs.iproute2}/bin/ip netns exec "$NAMESPACE" "$APP_ID" "$@"
      '')
    ];

    # Generate desktop files for each VPN app
    home.file = builtins.listToAttrs (map (
        app: let
          appName =
            if app.flatpakId != null
            then app.flatpakId
            else app.name;
          argsStr =
            if app.args != []
            then " " + (builtins.concatStringsSep " " app.args)
            else "";
          command =
            if app.flatpakId != null
            then "${pkgs.flatpak}/bin/flatpak run ${app.flatpakId}${argsStr}"
            else "${app.command}${argsStr}";
          desktopName = "${appName}-vpn";
        in {
          name = ".local/share/applications/${desktopName}.desktop";
          value = {
            text = ''
              [Desktop Entry]
              Name=${app.name} (VPN)
              Comment=Run ${app.name} through VPN
              Exec=run-vpn-app ${lib.escapeShellArg command}
              Terminal=false
              Type=Application
              Categories=Network;
              StartupNotify=true
              X-VPN-App=true
            '';
          };
        }
      )
      cfg.apps);

    # Create systemd user service for each VPN app
    systemd.user.services = builtins.listToAttrs (map (
        app: let
          appName =
            if app.flatpakId != null
            then app.flatpakId
            else app.name;
          serviceName = "${lib.strings.sanitizeDerivationName appName}-vpn";
          argsStr =
            if app.args != []
            then " " + (builtins.concatStringsSep " " app.args)
            else "";
          command =
            if app.flatpakId != null
            then "${pkgs.flatpak}/bin/flatpak run ${app.flatpakId}${argsStr}"
            else "${app.command}${argsStr}";
        in {
          name = serviceName;
          value = {
            Unit = {
              Description = "Run ${app.name} through VPN";
              After = ["network-online.target"];
              Wants = ["network-online.target"];
            };

            Service = {
              Type = "simple";
              ExecStart = "${pkgs.writeShellScript "run-${serviceName}" ''
                exec run-vpn-app ${lib.escapeShellArg command}
              ''}";
              Restart = "on-failure";
              RestartSec = "5s";
            };

            Install = {
              WantedBy = ["default.target"];
            };
          };
        }
      )
      cfg.apps);
  };
}
