# This file bridges the system and home-manager configurations for 'scripts'.
{ username, ... }: {
  # System-level configurations for scripts
  imports = [ ./system/default.nix ];

  # User-level (home-manager) configurations for scripts
  home-manager.users.${username} = {
    imports = [ ./hm/default.nix ];
  };
}
