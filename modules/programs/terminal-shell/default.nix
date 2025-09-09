{username, ...}: {
  imports = [
    ./system.nix
  ];

  home-manager.users."protect-${username}" = {
    imports = [
      ./hm
    ];
  };
}
