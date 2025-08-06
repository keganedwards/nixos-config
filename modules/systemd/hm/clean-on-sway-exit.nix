{pkgs, ...}: {
  systemd.user.services."cleanup-on-sway-exit" = {
    Unit = {
      Description = "Kill Brave browser on graphical session shutdown";
      # Binds this service to the graphical session's lifetime.
      # When graphical-session.target stops, this service stops.
      PartOf = ["graphical-session.target"];
    };

    Service = {
      Type = "oneshot";
      # The service doesn't run anything on start, but we need RemainAfterExit
      # so that systemd keeps track of it until the target stops.
      RemainAfterExit = true;
      # Command to run when this service is stopped
      ExecStop = "${pkgs.procps}/bin/pkill brave";
      # Alternative using killall (requires pkgs.psmisc instead of pkgs.procps)
      # ExecStop = "${pkgs.psmisc}/bin/killall brave";
    };

    Install = {
      # Ensure this service is "wanted" by the graphical session target,
      # meaning it gets started (and thus tracked) when the session starts.
      WantedBy = ["graphical-session.target"];
    };
  };
}
