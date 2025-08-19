# This file bridges the system and home-manager configurations for 'programs'.
{username, ...}: {
  # System-level configurations for programs
  imports = [./system/default.nix];

  # User-level (home-manager) configurations for programs
  home-manager.users.${username} = {
    imports = [./hm/default.nix];
  };
}
