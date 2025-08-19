# This file bridges the system and home-manager configurations for 'systemd'.
{username, ...}: {
  # System-level configurations for systemd
  imports = [./system/default.nix];

  # User-level (home-manager) configurations for systemd
  home-manager.users.${username} = {
    imports = [./hm/default.nix];
  };
}
