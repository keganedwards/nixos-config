# /modules/boot.nix
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
    # This is not a boot option, so it remains at the top level.
    environment.systemPackages = [pkgs.clevis pkgs.tpm2-tools];

    # All boot-related options are now grouped under this single attribute set.
    boot = {
      loader = {
        systemd-boot.enable = false;
        grub = {
          enable = true;
          efiSupport = true;
          device = "nodev";
        };
        efi.canTouchEfiVariables = true;
      };

      initrd = {
        systemd.enable = true;
        kernelModules = ["tpm_crb" "tpm_tis" "tpm_tis_core" "tpm"];

        luks.devices =
          lib.mapAttrs'
          (_partitionName: partitionCfg:
            lib.nameValuePair partitionCfg.luksName {
              device = partitionCfg.devicePath;
            })
          config.custom.boot.luksPartitions;

        clevis = {
          enable = true;
          devices =
            lib.mapAttrs'
            (_partitionName: partitionCfg:
              lib.nameValuePair partitionCfg.luksName {
                secretFile = jweFilePath;
              })
            config.custom.boot.luksPartitions;
        };

        secrets = lib.optionalAttrs (builtins.pathExists jweFilePath) {
          "${jweFilePath}" = jweFilePath;
        };
      };
    };
  };
}
