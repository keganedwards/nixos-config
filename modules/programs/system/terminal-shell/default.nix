# /modules/system/terminal-shell/default.nix
#
# This is the entrypoint for the 'terminal-shell' feature.
# It imports the system and home-manager configurations correctly.
{username, ...}: {
  # Import all the NixOS options for this feature.
  imports = [./system.nix];

  # Apply the Home Manager options for this feature to the specified user.
  home-manager.users.${username} = {
    imports = [./hm.nix];
  };
}
