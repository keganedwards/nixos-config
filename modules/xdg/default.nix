# This file bridges the system and home-manager configurations for 'xdg'.
{ username, ... }: {
  # System-level configurations for xdg
  imports = [ ./system.nix ];

  # User-level (home-manager) configurations for xdg
  home-manager.users.${username} = {
    imports = [ ./hm.nix ];
  };
}
