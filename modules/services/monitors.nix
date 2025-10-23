# monitors.nix
{username, ...}: {
  home-manager.users.${username} = {
    services.way-displays = {
      enable = true;
      settings = {
        NOTIFY = false;
      };
    };
  };
}
