{pkgs, ...}: {
  # This block defines the systemd service for the Vopono daemon.
  systemd.services.vopono = {
    description = "Vopono root daemon";
    after = ["network.target"];
    requires = ["network.target"];

    # This provides all the necessary binary dependencies to the service's PATH.
    # This was the solution to all the "command not found" and firewall errors.
    path = [
      pkgs.iptables-legacy # For compatibility with Vopono's firewall scripts
      pkgs.iproute2 # Provides the 'ip' command
      pkgs.procps # Provides the 'sysctl' command
      pkgs.openvpn # Provides the 'openvpn' command
    ];

    # Standard service configuration.
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.vopono}/bin/vopono daemon";
      Restart = "on-failure";
      RestartSec = "2s";
      Environment = "RUST_LOG=info";
    };

    # This ensures the service starts on boot.
    wantedBy = ["multi-user.target"];
  };

  # This makes the 'vopono' and 'openvpn' commands available to your user.
  environment.systemPackages = [pkgs.vopono pkgs.openvpn];
}
