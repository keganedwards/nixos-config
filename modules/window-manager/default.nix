{username, ...}: {
  programs.sway = {
    enable = true;
    extraPackages = [];
  };

  imports = [
    ./workspaces.nix

    ./startup.nix
  ];

  home-manager.users.${username} = {
    imports = [
      ./hm-environment.nix
      ./hm-appearance.nix
      ./hm-input.nix
      ./hm-keybindings.nix
      ./hm-window-rules.nix
      ./hm-lock-screen.nix
      ./clipboard-manager.nix
    ];
  };
}
