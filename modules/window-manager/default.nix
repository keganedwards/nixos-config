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
      ./hm-environment.nix
      ./hm-appearance.nix
      ./hm-input.nix
      ./hm-keybindings.nix
      ./hm-window-rules.nix
      ./hm-startup.nix
      ./hm-workspaces.nix
      ./hm-lock-screen.nix
      ./clipboard-manager.nix
    ];
  };
}
