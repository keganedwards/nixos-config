{username, ...}: {
  imports = [
    ./system.nix
  ];

  home-manager.users.${username} = {
    imports = [
      ./hm
    ];
  };
}
