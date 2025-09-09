{
  pkgs,
  username,
  ...
}: let
  protectedUsername = "protect-${username}";
in {
  # Protected user owns the configuration
  home-manager.users.${protectedUsername} = {
    programs.git.delta.enable = true;
  };

  # Main user just gets the package
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      delta
    ];
  };
}
