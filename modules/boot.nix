# /etc/nixos/modules/nixos/boot.nix
{
  lib,
  config,
  pkgs,
  ...
}: let
  jweFilePath = "/etc/clevis-secrets/secret.jwe";
in {
  options.custom.boot = {
    luksPartitions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          luksName = lib.mkOption {
            type = lib.types.str;
            description = "The logical name for the LUKS device";
          };
          devicePath = lib.mkOption {
            type = lib.types.str;
            description = "The persistent path to the LUKS-encrypted block device";
          };
        };
      });
      default = {};
    };
  };

  config = lib.mkIf (config.custom.boot.luksPartitions != {}) {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.initrd.systemd.enable = true;

    boot.initrd.kernelModules = ["tpm_crb" "tpm_tis" "tpm_tis_core" "tpm"];
    environment.systemPackages = [pkgs.clevis pkgs.tpm2-tools];

    boot.initrd.luks.devices =
      lib.mapAttrs'
      (partitionName: partitionCfg:
        lib.nameValuePair partitionCfg.luksName {
          device = partitionCfg.devicePath;
        })
      config.custom.boot.luksPartitions;

    boot.initrd.clevis = {
      enable = true;
      devices =
        lib.mapAttrs'
        (partitionName: partitionCfg:
          lib.nameValuePair partitionCfg.luksName {
            secretFile = jweFilePath;
          })
        config.custom.boot.luksPartitions;
    };

    boot.initrd.secrets = lib.optionalAttrs (builtins.pathExists jweFilePath) {
      "${jweFilePath}" = jweFilePath;
    };
  };
}
