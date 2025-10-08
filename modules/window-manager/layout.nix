{
  # Visual and layout configuration for niri
  programs.niri.settings = {
    # Disable animations for workspace switching
    animations = {
      workspace-switch.enable = false;
      window-open.enable = false;
      window-close.enable = false;
      horizontal-view-movement.enable = false;
      window-movement.enable = false;
      window-resize.enable = false;
      config-notification-open-close.enable = false;

      # Set all animation durations to 0 for instant transitions
      slowdown = 0.0;
    };

    # Layout configuration
    layout = {
      # Remove gaps between windows and screen edges
      gaps = 0;

      # Make windows take full width by default
      default-column-width = {proportion = 1.0;};

      # Center the focused column
      center-focused-column = "always";

      # Preset widths for columns (all full width)
      preset-column-widths = [
        {proportion = 1.0;}
      ];

      # Remove borders
      border = {
        enable = false;
        width = 0;
      };

      # Remove focus ring
      focus-ring = {
        enable = false;
        width = 0;
      };

      # Disable struts (panels reserving space)
      struts = {
        left = 0;
        right = 0;
        top = 0;
        bottom = 0;
      };
    };

    # Prefer no CSD (Client-Side Decorations) to remove window chrome
    prefer-no-csd = true;

    # Additional window rules to ensure fullscreen behavior for all windows
    window-rules = [
      {
        # Match all windows
        matches = [];
        # Set them to use full column width
        default-column-width = {};
        # Maximize them by default
        open-maximized = true;
      }
    ];
  };
}
