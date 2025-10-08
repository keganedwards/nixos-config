{
  # --- Input Device Configuration ---
  programs.niri.settings.input = {
    keyboard = {
      xkb = {
        layout = "us";
        options = "lv5:caps_switch"; # Make Caps Lock act as ISO_Level5_Shift
      };
    };
    mouse = {
      accel-profile = "flat";
    };
    touchpad = {
      accel-profile = "flat";
    };
  };
}
