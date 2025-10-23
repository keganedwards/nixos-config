{username, ...}: {
  home-manager.users.${username}.programs.niri.settings.window-rules = [
    {
      matches = [];
      default-column-width = {};
      open-maximized = true;
    }
  ];
}
