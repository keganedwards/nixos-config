# ~/nixos-config/flake.nix
{
  description = "NixOS & Home Manager configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-flatpak = {
      url = "github:gmodena/nix-flatpak?ref=latest";
    };
    nvf = {
      url = "github:notashelf/nvf";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
    sops-nix,
    nix-flatpak,
    catppuccin,
    nvf,
  }: let
    stateVersion = "23.11";

    allUsers = {
      keganedwards = {
        fullName = "Kegan Riley Edwards";
        email = "keganedwards@proton.me";
      };
    };

    hosts = {
      desktop = {
        system = "x86_64-linux";
        username = "keganedwards";
        path = ./hosts/desktop;
      };
      laptop = {
        system = "x86_64-linux";
        username = "keganedwards";
        path = ./hosts/laptop;
      };
    };

    hostArgs = {
      system,
      hostname,
      username,
      fullName,
      email,
    }: {
      inherit inputs;
      inherit self nixpkgs home-manager sops-nix nix-flatpak catppuccin nvf system hostname;
      inherit username fullName email;
      flakeDir = "/home/${username}/nixos-config";
      flakeConstants = import ./flake-constants.nix {
        lib = nixpkgs.lib;
        pkgs = nixpkgs.legacyPackages.${system};
        inherit stateVersion hostname;
      };
    };

    nixosConfigurations =
      nixpkgs.lib.mapAttrs (
        hostname: hostParams: let
          hostUsername = hostParams.username;
          userDetails = allUsers.${hostUsername};
          argsBase = hostArgs {
            system = hostParams.system;
            inherit hostname;
            username = hostUsername;
            fullName = userDetails.fullName;
            email = userDetails.email;
          };
        in
          nixpkgs.lib.nixosSystem {
            system = hostParams.system;
            specialArgs = argsBase;
            modules = [
              {
                system.stateVersion = stateVersion;
                networking.hostName = hostname;
              }
              argsBase.home-manager.nixosModules.home-manager
              argsBase.sops-nix.nixosModules.sops
              argsBase.catppuccin.nixosModules.catppuccin
              ./modules
              hostParams.path
              {home-manager.extraSpecialArgs = argsBase;}
            ];
          }
      )
      hosts;
  in {
    inherit nixosConfigurations;
  };
}
# Test comment Mon Aug 11 06:22:21 PM EDT 2025
# Test comment Mon Aug 11 06:23:49 PM EDT 2025
