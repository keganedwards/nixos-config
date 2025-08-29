{
  programs = {
    # Enable gamescope globally and grant it CAP_SYS_NICE for better performance
    gamescope = {
      enable = true;
      capSysNice = true;
    };

    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers

      # Enable and configure the gamescope session for Steam
      gamescopeSession = {
        enable = true;

        # These arguments will be applied to all games launched from the session.
        # The system automatically handles adding the %command% part.
        args = [
          "-w"
          "3840"
          "-h"
          "2160"
          "--immediate-flips"
        ];
      };
    };
  };
}
