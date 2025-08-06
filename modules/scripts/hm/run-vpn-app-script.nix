# File: modules/home-manager/scripts/run-vpn-app-script.nix
{pkgs, ...}: {
  home.packages = [
    (pkgs.writeShellScriptBin "run-vpn-app" ''
      #!${pkgs.bash}/bin/bash
      set -eu

      # The namespace name must match what the service creates
      NAMESPACE="vo_pr_us"

      # Check if an application was provided
      if [ "$#" -lt 1 ]; then
        echo "Error: No application specified."
        echo "Usage: $(basename "$0") <application> [arguments...]"
        exit 1
      fi

      # Get the application name and resolve its path
      APP="$1"
      shift

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

      # Find the full path of the application
      APP_PATH=$(which "$APP" 2>/dev/null || echo "$APP")

      # If not found in PATH, check common locations
      if [ ! -x "$APP_PATH" ]; then
        for dir in /run/current-system/sw/bin ~/.nix-profile/bin /etc/profiles/per-user/$USER/bin; do
          if [ -x "$dir/$APP" ]; then
            APP_PATH="$dir/$APP"
            break
          fi
        done
      fi

      if [ ! -x "$APP_PATH" ]; then
        echo "Error: Cannot find executable: $APP"
        exit 1
      fi

      # Run application in namespace using firejail
      echo "Launching $APP_PATH in VPN namespace..."
      exec firejail --noprofile --netns="$NAMESPACE" "$APP_PATH" "$@"
    '')

    # Helper script to check VPN status
    (pkgs.writeShellScriptBin "vpn-status" ''
      #!${pkgs.bash}/bin/bash

      echo "=== VPN Namespace Service Status ==="
      systemctl status vpn-namespace.service --no-pager

      echo -e "\n=== Network Namespaces ==="
      ${pkgs.iproute2}/bin/ip netns list 2>/dev/null || echo "No namespaces found (may need sudo)"

      echo -e "\n=== Test VPN Connection ==="
      NAMESPACE="vo_pr_us"
      if ${pkgs.iproute2}/bin/ip netns list 2>/dev/null | grep -q "^$NAMESPACE"; then
        echo "Testing connection from VPN namespace..."
        firejail --noprofile --netns="$NAMESPACE" ${pkgs.curl}/bin/curl -s ifconfig.co/country || echo "Connection test failed"
      else
        echo "Namespace not found or no permission to check"
      fi
    '')
  ];
}
