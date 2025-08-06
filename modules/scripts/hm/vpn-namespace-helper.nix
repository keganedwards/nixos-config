# modules/home-manager/scripts/vpn-namespace-helper.nix
{pkgs, ...}: {
  home.packages = [
    (pkgs.writeShellScriptBin "vpn-exec" ''
      #!${pkgs.bash}/bin/bash
      set -eu

      NAMESPACE="vo_pr_us"

      # Check if namespace exists
      if ! ${pkgs.iproute2}/bin/ip netns list 2>/dev/null | grep -q "^$NAMESPACE"; then
        echo "Error: VPN namespace $NAMESPACE not found."
        echo "The VPN service may not be running."
        echo "Try: sudo systemctl start vpn-namespace.service"
        exit 1
      fi

      # Get the command to run
      if [ "$#" -lt 1 ]; then
        echo "Error: No command specified."
        echo "Usage: $(basename "$0") <command> [arguments...]"
        exit 1
      fi

      # Run the specified command through the VPN namespace
      exec sudo ${pkgs.iproute2}/bin/ip netns exec "$NAMESPACE" "$@"
    '')

    (pkgs.writeShellScriptBin "vpn-flatpak" ''
      #!${pkgs.bash}/bin/bash
      set -eu

      NAMESPACE="vo_pr_us"

      # Check if namespace exists
      if ! ${pkgs.iproute2}/bin/ip netns list 2>/dev/null | grep -q "^$NAMESPACE"; then
        echo "Error: VPN namespace $NAMESPACE not found."
        echo "The VPN service may not be running."
        echo "Try: sudo systemctl start vpn-namespace.service"
        exit 1
      fi

      # Get the flatpak ID
      if [ "$#" -lt 1 ]; then
        echo "Error: No Flatpak ID specified."
        echo "Usage: $(basename "$0") <flatpak-id> [arguments...]"
        exit 1
      fi

      FLATPAK_ID="$1"
      shift

      # Run flatpak through the VPN namespace
      exec sudo ${pkgs.iproute2}/bin/ip netns exec "$NAMESPACE" ${pkgs.flatpak}/bin/flatpak run "$FLATPAK_ID" "$@"
    '')

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
        sudo ${pkgs.iproute2}/bin/ip netns exec "$NAMESPACE" ${pkgs.curl}/bin/curl -s ifconfig.co/country || echo "Connection test failed"
      else
        echo "Namespace not found or no permission to check"
      fi
    '')
  ];
}
