# /modules/protected-user.nix
{
  username,
  fullName,
  flakeConstants,
  ...
}: let
  protectedUsername = "protect-${username}";
in {
  # Create the protected user account
  users.users.${protectedUsername} = {
    isSystemUser = true;
    description = "Protected configuration for ${fullName}";
    home = "/var/lib/protected-${username}";
    createHome = true;
    group = "protected-users";
    # No login capability
    shell = "/run/current-system/sw/bin/nologin";
  };

  # Create a group for protected users
  users.groups.protected-users = {};

  # Home-manager configuration for protected user
  home-manager.users.${protectedUsername} = {
    home.stateVersion = flakeConstants.stateVersion;
    home.homeDirectory = "/var/lib/protected-${username}";
  };
}
