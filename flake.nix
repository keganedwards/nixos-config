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
    pre-commit-hooks = {
      url = "github:cachix/git-hooks.nix";
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
    pre-commit-hooks,
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

    supportedSystems = ["x86_64-linux" "aarch64-linux"];
    forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
  in {
    inherit nixosConfigurations;

    checks = forAllSystems (system: {
      pre-commit-check = pre-commit-hooks.lib.${system}.run {
        src = ./.;
        hooks = {
          # Secret Detection
          ripsecrets.enable = true;
          detect-private-keys.enable = true;

          # Git & File Hygiene
          check-added-large-files.enable = true;
          check-case-conflicts.enable = true;
          check-merge-conflicts.enable = true;
          check-symlinks.enable = true;
          forbid-new-submodules.enable = true;

          # File Formatting
          end-of-file-fixer.enable = true;
          trim-trailing-whitespace.enable = true;

          # File Syntax Checks
          check-json.enable = true;
          check-toml.enable = true;

          # Nix
          deadnix.enable = true;

          # Spellchecker
          typos.enable = true;
        };
      };
    });

    devShells = forAllSystems (system: {
      default = nixpkgs.legacyPackages.${system}.mkShell {
        inherit (self.checks.${system}.pre-commit-check) shellHook;
        buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
      };
    });
  };
}
