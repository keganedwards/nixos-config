# /etc/nixos/vpn-apps.nix
{
  config,
  pkgs,
  lib,
  username,
  ...
}: let
  # Get the home-manager configuration for the user
  hmConfig = config.home-manager.users.${username};

  # Extract apps that need VPN
  vpnApps = lib.filterAttrs (
    _name: app: (app.vpn or {}).enabled or false
  ) (hmConfig.applications or {});
in {
  # Create systemd services for each VPN app
  systemd.services =
    lib.mapAttrs' (
      name: app: let
        # Map provider names to their correct CLI format
        providerMapping = {
          "protonvpn" = "ProtonVPN";
          "proton" = "ProtonVPN";
          "pia" = "PrivateInternetAccess";
          "privateinternetaccess" = "PrivateInternetAccess";
          "mullvad" = "Mullvad";
          "mozilla" = "MozillaVPN";
          "mozillavpn" = "MozillaVPN";
          "azirevpn" = "AzireVPN";
          "airvpn" = "AirVPN";
          "ivpn" = "IVPN";
          "nordvpn" = "NordVPN";
          "hma" = "HMA";
          "warp" = "Warp";
          "custom" = "Custom";
          "none" = "None";
        };

        rawProvider = app.vpn.provider or "protonvpn";
        lowerProvider = lib.strings.toLower rawProvider;
        provider = providerMapping.${lowerProvider} or rawProvider;

        server = app.vpn.server or "us";
        protocol = app.vpn.protocol or "openvpn";

        # Detect if this is a flatpak app (contains dots like com.example.App)
        isFlatpak = lib.strings.hasInfix "." app.id;

        # Construct the command to run
        appCommand =
          if isFlatpak
          then "flatpak run ${app.id}"
          else app.id;
      in
        lib.nameValuePair "vpn-app-${lib.strings.sanitizeDerivationName name}" {
          description = "Run ${app.id} through VPN";
          after = ["network-online.target"];
          wants = ["network-online.target"];

          startLimitIntervalSec = 300;
          startLimitBurst = 3;

          preStart = ''
            # Set PATH to include network utilities
            export PATH=/run/wrappers/bin:/run/current-system/sw/bin:${pkgs.iproute2}/bin:${pkgs.iptables}/bin:$PATH

            # Clean up any existing vopono namespaces
            echo "Cleaning up existing vopono namespaces..."
            ${pkgs.vopono}/bin/vopono list namespaces | tail -n +2 | while read ns rest; do
              if [ -n "$ns" ]; then
                echo "Removing existing namespace: $ns"
                ip netns delete "$ns" 2>/dev/null || true
              fi
            done

            # Clean up any veth interfaces that might be left over
            echo "Cleaning up veth interfaces..."
            ip link show | grep "vo_.*_d" | cut -d: -f2 | tr -d ' ' | while read iface; do
              echo "Removing interface: $iface"
              ip link delete "$iface" 2>/dev/null || true
            done

            # Wait for cleanup
            sleep 2
          '';

          script = ''
            # Set environment variables
            export HOME=/home/${username}
            export USER=${username}
            export XDG_CONFIG_HOME=/home/${username}/.config
            export PATH=/run/wrappers/bin:/run/current-system/sw/bin:$PATH

            echo "Running as user: $(whoami)"
            echo "Application ID: ${app.id}"
            echo "Is Flatpak: ${
              if isFlatpak
              then "yes"
              else "no"
            }"
            echo "Command to execute: ${appCommand}"

            # Check if the application exists
            ${
              if isFlatpak
              then ''
                if sudo -u ${username} flatpak list --app | grep -q "${app.id}"; then
                  echo "Flatpak application ${app.id} found"
                else
                  echo "ERROR: Flatpak application ${app.id} not found"
                  echo "Available flatpak apps:"
                  sudo -u ${username} flatpak list --app | head -5
                  exit 1
                fi
              ''
              else ''
                if command -v ${app.id} >/dev/null 2>&1; then
                  echo "Application ${app.id} found at: $(command -v ${app.id})"
                else
                  echo "ERROR: Application ${app.id} not found in PATH"
                  echo "Current PATH: $PATH"
                  exit 1
                fi
              ''
            }

            # Run vopono with the application
            echo "Running vopono with provider ${provider}, server ${server}, protocol ${protocol}"
            exec ${pkgs.vopono}/bin/vopono -v exec \
              --provider ${provider} \
              --server ${server} \
              --protocol ${protocol} \
              "sudo -u ${username} ${appCommand}"
          '';

          serviceConfig = {
            Type = "simple";
            User = "root";
            Group = "root";

            WorkingDirectory = "/home/${username}";
            Restart = "on-failure";
            RestartSec = "30s";

            Environment = [
              "DISPLAY=:0"
              "WAYLAND_DISPLAY=wayland-0"
              "XDG_RUNTIME_DIR=/run/user/${toString config.users.users.${username}.uid}"
              "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${toString config.users.users.${username}.uid}/bus"
            ];

            StandardOutput = "journal";
            StandardError = "journal";
          };

          wantedBy =
            if (app.autostart or false)
            then ["multi-user.target"]
            else [];
        }
    )
    vpnApps;

  # Install required packages
  environment.systemPackages = with pkgs; [
    vopono
    openvpn
    wireguard-tools
    iproute2 # For ip command
    iptables # For iptables command
    flatpak # For flatpak apps
  ];
}
