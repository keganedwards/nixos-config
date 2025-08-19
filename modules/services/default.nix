# This file bridges the system and home-manager configurations for 'services'.
{username, ...}: {
  # System-level configurations for services
  imports = [./system/default.nix];

  # User-level (home-manager) configurations for services
  home-manager.users.${username} = {
    imports = [./hm/default.nix];
  };
}
