# File: nixos/home-manager-modules/scripts/default.nix
{
  imports = [
    ./vpn-app-launcher.nix
    ./move-to-scratchpad-script.nix
  ];
}
