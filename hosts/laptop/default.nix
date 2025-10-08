{
  inputs,
  username,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./boot.nix
    ./power-management.nix
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480s
  ];

  home-manager.users.${username} = {
    imports = [
      ./battery-notifier.nix
      ./monitors.nix
    ];
  };
}
