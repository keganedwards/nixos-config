# protected-user.nix
{
  username,
  fullName,
  stateVersion,
  ...
}: let
  protectedUsername = "protect-${username}";
in {
  users = {
    users.${protectedUsername} = {
      isSystemUser = true;
      description = "Protected configuration for ${fullName}";
      home = "/var/lib/protected-${username}";
      createHome = true;
      group = "protected-users";
      shell = "/run/current-system/sw/bin/nologin";
    };

    groups.protected-users = {};
  };

  home-manager.users.${protectedUsername} = {
    home = {
      inherit stateVersion;
      homeDirectory = "/var/lib/protected-${username}";
    };
  };
}
