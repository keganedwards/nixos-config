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

  # Get the user's primary group
  primaryGroup = config.users.users.${username}.group;
in {
  # Create systemd services for each VPN app
  systemd.services =
    lib.mapAttrs' (
      name: app:
        lib.nameValuePair "vpn-app-${lib.strings.sanitizeDerivationName name}" {
          description = "Run ${app.id} through VPN";
          after = ["network-online.target"];
          wants = ["network-online.target"];

          script = ''
            # Set environment variables
            export HOME=/home/${username}
            export USER=${username}
            export XDG_CONFIG_HOME=/home/${username}/.config

            # Print debugging information
            echo "Running as user: $(whoami)"
            echo "HOME is set to: $HOME"
            echo "Looking for vopono config in: $HOME/.config/vopono"
            ls -la $HOME/.config/vopono || echo "Directory not found"

            # Set correct permissions for config files if they exist
            if [ -d "$HOME/.config/vopono" ]; then
              chown -R ${username}:${primaryGroup} $HOME/.config/vopono
              chmod -R 755 $HOME/.config/vopono
            fi

            # Copy config from root if needed
            if [ ! -d "$HOME/.config/vopono" ] && [ -d "/root/.config/vopono" ]; then
              mkdir -p $HOME/.config/vopono
              cp -r /root/.config/vopono/* $HOME/.config/vopono/
              chown -R ${username}:${primaryGroup} $HOME/.config/vopono
              chmod -R 755 $HOME/.config/vopono
            fi

            # Run vopono with verbose flag to see more details
            exec ${pkgs.vopono}/bin/vopono -v exec \
              --provider ${app.vpn.provider or "protonvpn"} \
              --server ${app.vpn.server or "us"} \
              --protocol ${app.vpn.protocol or "openvpn"} \
              "sudo -u ${username} ${app.id}"
          '';

          serviceConfig = {
            Type = "simple";
            User = "root";
            Group = "root";

            # Set the working directory to the user's home
            WorkingDirectory = "/home/${username}";

            # Restart policy
            Restart = "on-failure";
            RestartSec = "30s";
            StartLimitBurst = 3;
            StartLimitIntervalSec = 300;

            # Environment for GUI applications
            Environment = [
              "DISPLAY=:0"
              "WAYLAND_DISPLAY=wayland-0"
              "XDG_RUNTIME_DIR=/run/user/${toString config.users.users.${username}.uid}"
              "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/${toString config.users.users.${username}.uid}/bus"
            ];

            # Send stdout/stderr to journal for debugging
            StandardOutput = "journal";
            StandardError = "journal";
          };

          # Enable automatic startup if the app has autostart set
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
  ];
}
