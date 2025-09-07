# /modules/themeing.nix
{
  username,
  catppuccin,
  ...
}: let
  catflavor = "latte";
in {
  catppuccin = {
    enable = true;
    flavor = catflavor;

    cache.enable = true;
  };

  home-manager.users.${username} = {
    imports = [
      # Import the Catppuccin Home Manager module to define user-level options.
      catppuccin.homeModules.catppuccin
    ];

    catppuccin = {
      enable = true;
      flavor = catflavor;
      wlogout.enable = false;
    };
  };
}
