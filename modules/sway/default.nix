{username, ...}: {
  programs.sway = {
    enable = true;
    extraPackages = [];
  };

  imports = [
    ./greetd.nix
  ];

  home-manager.users.${username} = {
    imports = [
      ./hm-base.nix
      ./hm-startup.nix
      ./hm-workspaces.nix
      ./hm-logout.nix
      ./hm-lock-screen.nix
      ./hm-sway-config.nix
      ./clipboard-manager.nix
    ];
  };
}
