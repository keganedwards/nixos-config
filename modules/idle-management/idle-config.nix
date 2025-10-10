{
  pkgs,
  windowManagerConstants,
  ...
}: let
  lockscreenScript = import ./lockscreen.nix {inherit pkgs;};

  # Get display control command from window manager constants
  displayControl = status: "${windowManagerConstants.msg} action power-${status}-monitors";

  # Idle timeouts (in seconds)
  timeouts = {
    notification = 4 * 60; # 4 minutes
    lock = 5 * 60; # 5 minutes
    displayOff = 7 * 60; # 7 minutes
    suspend = 15 * 60; # 15 minutes
  };
in {
  enable = true;

  timeouts = [
    {
      timeout = timeouts.notification;
      command = "${pkgs.libnotify}/bin/notify-send 'Idle Timeout Warning' 'Screen will lock in 1 minute' -t 5000 -u normal";
    }
    {
      timeout = timeouts.lock;
      command = "${lockscreenScript}/bin/lockscreen";
    }
    {
      timeout = timeouts.displayOff;
      command = displayControl "off";
      resumeCommand = displayControl "on";
    }
    {
      timeout = timeouts.suspend;
      command = "${pkgs.systemd}/bin/systemctl suspend";
    }
  ];

  events = [
    {
      event = "before-sleep";
      command = "${displayControl "off"}; ${lockscreenScript}/bin/lockscreen";
    }
    {
      event = "after-resume";
      command = displayControl "on";
    }
    {
      event = "lock";
      command = "${displayControl "off"}; ${lockscreenScript}/bin/lockscreen";
    }
    {
      event = "unlock";
      command = displayControl "on";
    }
  ];
}
