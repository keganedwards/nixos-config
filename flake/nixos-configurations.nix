{inputs, ...}: {
  flake = let
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
        path = ../hosts/desktop;
      };
      laptop = {
        system = "x86_64-linux";
        username = "keganedwards";
        path = ../hosts/laptop;
      };
    };

    makeConstants = system: username: let
      pkgs = inputs.nixpkgs.legacyPackages.${system};
      inherit (inputs.nixpkgs) lib;
      allConstants = import ../constants {
        inherit pkgs lib username;
      };
    in
      allConstants;

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
      inherit (inputs) self nixpkgs home-manager niri sops-nix nix-flatpak catppuccin nvf nixos-hardware;
      inherit system hostname username fullName email stateVersion;
      flakeDir = "/home/${username}/nixos-config";

      windowManagerConstants = constants.windowManager;
      terminalConstants = constants.terminal;
      terminalShellConstants = constants.terminalShell;
      editorConstants = constants.editor;
      mediaPlayerConstants = constants.mediaPlayer;
      browserConstants = constants.browser;
    };

    nixosConfigurations =
      inputs.nixpkgs.lib.mapAttrs (
        hostname: hostParams: let
          hostUsername = hostParams.username;
          userDetails = allUsers.${hostUsername};
          argsBase = hostArgs {
            inherit (hostParams) system;
            inherit hostname;
            username = hostUsername;
            inherit (userDetails) fullName email;
          };
        in
          inputs.nixpkgs.lib.nixosSystem {
            inherit (hostParams) system;
            specialArgs = argsBase;
            modules = [
              {
                system.stateVersion = stateVersion;
                networking.hostName = hostname;
                nix.settings = {
                  substituters = [
                    "https://cache.nixos.org/"
                    "https://pre-commit-hooks.cachix.org"
                  ];
                  trusted-public-keys = [
                    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
                    "pre-commit-hooks.cachix.org-1:Pkk3Panw5AW24TOv6kz3PvLhlH8puAsJTBbOPmBo7Rc="
                  ];
                };
              }
              argsBase.home-manager.nixosModules.home-manager
              argsBase.sops-nix.nixosModules.sops
              argsBase.catppuccin.nixosModules.catppuccin
              inputs.nix-index-database.nixosModules.nix-index
              {programs.nix-index-database.comma.enable = true;}
              inputs.nvf.nixosModules.default
              inputs.niri.nixosModules.niri
              ../modules
              hostParams.path
              {
                home-manager.extraSpecialArgs = argsBase;
              }
            ];
          }
      )
      hosts;
  in {
    inherit nixosConfigurations;
  };
}
