# /modules/themeing.nix
{
  username,
  catppuccin,
  ...
}: let
  catflavor = "latte";
  protectedUsername = "protect-${username}";
in {
  catppuccin = {
    enable = true;
    flavor = catflavor;
    cache.enable = true;
  };

  # Protected user has the configuration
  home-manager.users.${protectedUsername} = {
    imports = [
      catppuccin.homeModules.catppuccin
    ];

    catppuccin = {
      enable = true;
      flavor = catflavor;
      wlogout.enable = false;
    };
  };

  # Main user gets same theming settings (copies from protected)
  home-manager.users.${username} = {
    imports = [
      catppuccin.homeModules.catppuccin
    ];

    catppuccin = {
      enable = true;
      flavor = catflavor;
      wlogout.enable = false;
    };
  };
}
