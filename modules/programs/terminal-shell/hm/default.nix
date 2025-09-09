# /modules/programs/terminal-shell/hm/default.nix
{username, ...}: {
  imports = [
    ./security.nix
  ];

  home-manager.users."protect-${username}" = {
    imports = [
      ./aliases.nix
      ./functions
      ./init.nix
    ];
    programs.fish = {
      enable = true;
    };
  };
}
