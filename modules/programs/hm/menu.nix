{
  pkgs,
  username,
  lib,
windowManagerConstants,
...
}:
let
  protectedUsername = "protect-${username}";
in
lib.mkMerge [
  {
    home-manager.users.${protectedUsername} = {
      programs.fuzzel.enable = true;
    };

    home-manager.users.${username} = {
      home.packages = with pkgs; [
        fuzzel
      ];
    };
  }

  (windowManagerConstants.setKeybinding "Mod+Alt+m" "exec fuzzel")
]
