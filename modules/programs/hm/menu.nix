{
  pkgs,
  username,
  ...
}: let
  protectedUsername = "protect-${username}";
in {
  # Protected user owns the configuration
  home-manager.users.${protectedUsername} = {
    programs.fuzzel.enable = true;
  };

  # Main user gets the package AND the keybinding (exception to the rule)
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      fuzzel
    ];

    wayland.windowManager.sway.config.keybindings."Mod4+Alt+m" = "exec fuzzel";
  };
}
