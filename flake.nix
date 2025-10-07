{
  description = "NixOS & Home Manager configurations";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    niri = {
      url = "github:sodiboo/niri-flake";
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
    nixos-hardware = {
      url = "github:NixOS/nixos-hardware";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
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
    nixos-hardware,
    nix-index-database,
    niri,
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

    # Generate constants for a given system and username
    makeConstants = system: username: let
      pkgs = nixpkgs.legacyPackages.${system};
      lib = nixpkgs.lib;
      allConstants = import ./constants {
        inherit pkgs lib username;
      };
    in allConstants;

    hostArgs = {
      system,
      hostname,
      username,
      fullName,
      email,
    }: let
      constants = makeConstants system username;
    in {
      inherit inputs;
      inherit self nixpkgs home-manager niri sops-nix nix-flatpak catppuccin nvf system hostname nixos-hardware;
      inherit username fullName email stateVersion;
      flakeDir = "/home/${username}/nixos-config";
      
      # Pass all constants through specialArgs
      windowManagerConstants = constants.windowManager;
      terminalConstants = constants.terminal;
      editorConstants = constants.editor;
      mediaPlayerConstants = constants.mediaPlayer;
      browserConstants = constants.browser;
    };

    nixosConfigurations =
      nixpkgs.lib.mapAttrs (
        hostname: hostParams: let
          hostUsername = hostParams.username;
          userDetails = allUsers.${hostUsername};
          argsBase = hostArgs {
            inherit (hostParams) system;
            inherit hostname;
            username = hostUsername;
            inherit (userDetails) fullName;
            inherit (userDetails) email;
          };
        in
          nixpkgs.lib.nixosSystem {
            inherit (hostParams) system;
            specialArgs = argsBase;
            modules = [
              {
                system.stateVersion = stateVersion;
                networking.hostName = hostname;
              }
              argsBase.home-manager.nixosModules.home-manager
              argsBase.sops-nix.nixosModules.sops
              argsBase.catppuccin.nixosModules.catppuccin
              nix-index-database.nixosModules.nix-index
              {programs.nix-index-database.comma.enable = true;}
              nvf.nixosModules.default
              niri.nixosModules.niri
              # Don't import ./constants anymore - it's handled via specialArgs
              ./modules
              hostParams.path
              {
                home-manager.extraSpecialArgs = argsBase;
              }
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
          ripsecrets.enable = true;
          detect-private-keys.enable = true;
          check-added-large-files.enable = true;
          check-case-conflicts.enable = true;
          check-merge-conflicts.enable = true;
          check-symlinks.enable = true;
          forbid-new-submodules.enable = true;
          alejandra.enable = true;
          typos.enable = true;
          statix = {
            enable = true;
            settings.ignore = [
              "**/hardware-configuration.nix"
            ];
          };
          deadnix = {
            enable = true;
            settings.edit = true;
          };
          flake-checker.enable = true;
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
