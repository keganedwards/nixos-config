{
  pkgs,
  username,
  faillock,
  ...
}: {
  systemd.tmpfiles.rules = [
    "d /run/faillock 0755 root root -"
    "d ${faillock.stateDir} 0755 root root -"
    "f ${faillock.stateDir}/auth-debug.log 0666 root root -"
  ];

  systemd.services.faillock-init = {
    description = "Initialize faillock directory";
    wantedBy = ["sysinit.target"];
    before = ["systemd-logind.service" "display-manager.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/mkdir -p /run/faillock ${faillock.stateDir}";
      RemainAfterExit = true;
    };
  };

  environment.systemPackages = [
    (faillock.mkCheckScript {inherit username;})
    (faillock.mkResetScript {inherit username;})
    pkgs.libnotify
    pkgs.ripgrep
    pkgs.linux-pam
  ];
}
