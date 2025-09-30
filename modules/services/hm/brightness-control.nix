{
  services.wluma = {
    enable = true;

    settings = {
      # Time-based ALS as a reliable fallback (no webcam needed)
      # Switch to als.webcam below if you want to try webcam-based sensing
      als.time = {
        # Simple day/night thresholds based on hour (0-23)
        thresholds = {
          "0" = "night"; # Midnight to 6am
          "6" = "dawn"; # 6am to 8am
          "8" = "day"; # 8am to 6pm
          "18" = "dusk"; # 6pm to 8pm
          "20" = "night"; # 8pm to midnight
        };
      };

      # Uncomment to use webcam instead of time-based ALS
      # als.webcam = {
      #   video = "/dev/video0";  # Standard ThinkPad webcam location
      #   thresholds = {
      #     "0" = "night";
      #     "20" = "dark";
      #     "80" = "dim";
      #     "250" = "normal";
      #     "500" = "bright";
      #     "800" = "outdoors";
      #   };
      # };

      # Output configuration for ThinkPad's internal display
      output.backlight = [
        {
          name = "eDP-1"; # Common name for internal laptop displays
          path = "/sys/class/backlight/intel_backlight"; # Intel graphics (most ThinkPads)
          # Use amdgpu_bl0 for AMD ThinkPads
          capturer = "wayland"; # Auto-selects best protocol
        }
      ];
    };
  };
}
