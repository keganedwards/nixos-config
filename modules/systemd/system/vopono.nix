{pkgs, ...}: {
  # Vopono daemon service with proper cleanup
  systemd.services.vopono = {
    description = "Vopono root daemon";
    after = ["network.target"];
    requires = ["network.target"];

    path = [
      pkgs.iptables
      pkgs.iproute2
      pkgs.procps
      pkgs.openvpn
      pkgs.util-linux
      pkgs.shadow
      pkgs.coreutils
      pkgs.bash
      "/run/current-system/sw/bin"
      "/run/wrappers/bin"
    ];

    serviceConfig = {
      Type = "simple";

      # More aggressive cleanup before starting
      ExecStartPre = pkgs.writeShellScript "vopono-cleanup" ''
        echo "Performing vopono cleanup..."

        # Kill any remaining openvpn processes from previous sessions
        pkill -f "openvpn.*vopono" 2>/dev/null || true

        # Remove ALL vopono-related network interfaces
        for iface in $(ip link show | grep -E 'vo_.*[@:]' | awk -F': ' '{print $2}' | cut -d@ -f1); do
          echo "Removing interface: $iface"
          ip link delete "$iface" 2>/dev/null || true
        done

        # Remove all vopono network namespaces
        for ns in $(ip netns list 2>/dev/null | grep '^vo_' | awk '{print $1}'); do
          echo "Removing namespace: $ns"
          ip netns delete "$ns" 2>/dev/null || true
        done

        # Clean up any stale lockfiles and sockets
        rm -f /run/vopono/*.lock 2>/dev/null || true
        rm -f /run/vopono.sock 2>/dev/null || true

        # Wait a moment for kernel to clean up
        sleep 1

        echo "Cleanup complete"
      '';

      ExecStart = "${pkgs.vopono}/bin/vopono daemon";

      # Cleanup on stop
      ExecStopPost = pkgs.writeShellScript "vopono-cleanup-stop" ''
        pkill -f "openvpn.*vopono" 2>/dev/null || true

        for iface in $(ip link show | grep -E 'vo_.*[@:]' | awk -F': ' '{print $2}' | cut -d@ -f1); do
          ip link delete "$iface" 2>/dev/null || true
        done

        for ns in $(ip netns list 2>/dev/null | grep '^vo_' | awk '{print $1}'); do
          ip netns delete "$ns" 2>/dev/null || true
        done

        rm -f /run/vopono/*.lock 2>/dev/null || true
      '';

      Restart = "on-failure";
      RestartSec = "2s";
      Environment = [
        "RUST_LOG=info"
        "PATH=/run/current-system/sw/bin:/run/wrappers/bin:${pkgs.lib.makeBinPath [
          pkgs.iptables
          pkgs.iproute2
          pkgs.procps
          pkgs.openvpn
          pkgs.util-linux
          pkgs.shadow
          pkgs.coreutils
          pkgs.bash
        ]}"
      ];
    };

    wantedBy = ["multi-user.target"];
  };

  # System-wide packages including launch scripts
  environment.systemPackages = [
    pkgs.vopono
    pkgs.openvpn

    # Main launch script - simplified to just work
    (pkgs.writeShellScriptBin "launch-vpn-app" ''
      #!${pkgs.bash}/bin/bash
      set -eu

      # Create the cache directory that flatpak might need
      mkdir -p "$HOME/.cache/doc/by-app"

      # Create a temporary wrapper script that exports the environment
      WRAPPER=$(mktemp /tmp/vopono-wrapper-XXXXXX.sh)
      chmod +x "$WRAPPER"

      # Write the wrapper script with the actual command embedded
      cat > "$WRAPPER" << WRAPPER_EOF
      #!/bin/sh
      export WAYLAND_DISPLAY="''${WAYLAND_DISPLAY:-wayland-1}"
      export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
      export XDG_SESSION_TYPE="''${XDG_SESSION_TYPE:-wayland}"
      export DISPLAY="''${DISPLAY:-:0}"
      export XAUTHORITY="''${XAUTHORITY:-$HOME/.Xauthority}"

      # Execute the actual command
      exec $@
      WRAPPER_EOF

      # Clean up the wrapper on exit
      trap "rm -f '$WRAPPER'" EXIT

      # Check if OpenVPN is already running for vopono
      if pgrep -f "openvpn.*vopono.*vo_pr_us" > /dev/null; then
        echo "VPN connection already active, using existing namespace"
        # Small delay to ensure namespace is ready
        sleep 0.5
      else
        echo "Starting new VPN connection"
        # Add delay for first app to ensure daemon is ready
        sleep 1
      fi

      # Run with retries
      MAX_RETRIES=10
      RETRY_COUNT=0

      while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if ${pkgs.vopono}/bin/vopono exec \
          --provider protonvpn \
          --server us \
          --protocol openvpn \
          "$WRAPPER" 2>&1 | tee /tmp/vopono-error-$$.log; then
          # Success
          rm -f /tmp/vopono-error-$$.log
          exit 0
        fi

        # Check error type
        if grep -qE "(No lockfile found|Cannot open network namespace|File exists|No such file)" /tmp/vopono-error-$$.log; then
          RETRY_COUNT=$((RETRY_COUNT + 1))
          if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
            # Shorter delay, more retries
            echo "Namespace issue, retry $RETRY_COUNT/$MAX_RETRIES..." >&2
            sleep 1
          else
            echo "Failed after $MAX_RETRIES attempts" >&2
            cat /tmp/vopono-error-$$.log >&2
            rm -f /tmp/vopono-error-$$.log
            exit 1
          fi
        else
          # Different error, don't retry
          rm -f /tmp/vopono-error-$$.log
          exit 1
        fi
      done
    '')

    # Manual cleanup command
  ];
}
