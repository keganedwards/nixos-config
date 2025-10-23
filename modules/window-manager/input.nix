{username, ...}: {
  home-manager.users.${username}.programs.niri.settings.input = {
    keyboard = {
      xkb = {
        layout = "us";
        options = "lv5:caps_switch";
      };
    };
    mouse.accel-profile = "flat";
    touchpad.accel-profile = "flat";
  };
}
