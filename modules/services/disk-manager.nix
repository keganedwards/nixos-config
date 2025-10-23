# disk-manager.nix
{username, ...}: {
  home-manager.users.${username} = {
    services.udiskie = {
      enable = true;
      automount = true;
    };
  };
}
