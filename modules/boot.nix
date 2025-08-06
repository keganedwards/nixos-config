# /etc/nixos/modules/nixos/boot.nix
{
  lib,
  config,
  pkgs,
  ...
}: let
  # Function to generate the expected path of the JWE file on the target system
  # Example: /etc/clevis-secrets/myLaptop-secret.jwe
  getJweFilePathOnSystem = hostname: "/etc/clevis-secrets/${hostname}-secret.jwe";
in {
  # Define options that host-specific configurations will set
  options.custom.boot = {
    luksPartitions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          luksName = lib.mkOption {
            type = lib.types.str;
            description = "The logical name for the LUKS device (e.g., 'luks-...). This is the name that appears under /dev/mapper/.";
          };
          devicePath = lib.mkOption {
            type = lib.types.str;
            description = "The persistent path to the LUKS-encrypted block device (e.g., /dev/disk/by-uuid/...).";
          };
          # We could add an option here if a partition uses a JWE file
          # not following the hostname convention, but for now, let's keep it simple.
        };
      });
      default = {};
      description = ''
        Attribute set of LUKS partitions to configure for Clevis TPM unlocking.
        The key of each attribute is a symbolic name for your reference (e.g., "root", "swap").
      '';
      example = ''
        {
          root = {
            luksName = "luks-59b3ba0d-4a20-49bb-9ad1-7215ca411a15";
            devicePath = "/dev/disk/by-uuid/59b3ba0d-4a20-49bb-9ad1-7215ca411a15";
          };
        }
      '';
    };
  };

  # Apply the configuration if there are LUKS partitions defined
  config = lib.mkIf (config.custom.boot.luksPartitions != {}) {
    # --- Bootloader (systemd-boot) ---
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true; # systemd-boot uses this to manage boot entries

    boot.initrd.systemd.enable = true; # Good for systemd-based initrd and Clevis

    # Ensure clevis tools are in initrd and on the system
    boot.initrd.kernelModules = ["tpm_crb" "tpm_tis" "tpm_tis_core" "tpm"]; # Common TPM modules
    environment.systemPackages = [pkgs.clevis]; # For clevis tools on the main system

    # --- LUKS Configuration ---
    boot.initrd.luks.devices =
      lib.mapAttrs'
      (partitionName: partitionCfg:
        lib.nameValuePair partitionCfg.luksName {
          device = partitionCfg.devicePath;
          # You could add other options like 'allowDiscards = true;' here if needed globally
        })
      config.custom.boot.luksPartitions;

    # --- Clevis Unattended Decryption ---
    boot.initrd.clevis = {
      enable = true;
      # Ensure systemd services for clevis are included if not pulled in automatically
      # initrdSystemdUnits = [ "clevis-luks-askpass.path" ]; # May be needed

      devices =
        lib.mapAttrs'
        (partitionName: partitionCfg:
          lib.nameValuePair partitionCfg.luksName {
            # This secretFile path is on the TARGET system's initrd root.
            # It's where Clevis expects to find the JWE token.
            # The JWE file itself must be created and placed on the target system manually
            # or through some other out-of-band mechanism (not through NixOS copying it from the config repo).
            secretFile = getJweFilePathOnSystem config.networking.hostName;
          })
        config.custom.boot.luksPartitions;
    };
  };
}
