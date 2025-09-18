{pkgs, ...}: {
  systemd.services.vopono = {
    description = "Vopono root daemon";
    after = ["network.target"];
    requires = ["network.target"];

    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.vopono}/bin/vopono daemon";
      Restart = "on-failure";
      RestartSec = "2s";
      Environment = "RUST_LOG=info";
    };

    # 3. Enable the service to start on boot
    wantedBy = ["multi-user.target"];
  };

  environment.systemPackages = [pkgs.vopono];
}
