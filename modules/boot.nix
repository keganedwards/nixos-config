{
  lib,
  config,
  pkgs,
  ...
}: {
  options.custom.boot = {
    luksPartitions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          luksName = lib.mkOption {type = lib.types.str;};
          devicePath = lib.mkOption {type = lib.types.str;};
          allowDiscards = lib.mkOption {
            type = lib.types.bool;
            default = true;
          };
        };
      });
      default = {};
    };
  };

  config = lib.mkIf (config.custom.boot.luksPartitions != {}) {
    environment.systemPackages = with pkgs; [
      cryptsetup
      tpm2-tools
      (pkgs.writeShellScriptBin "enroll-luks-tpm" ''
        #!/usr/bin/env bash
        set -euo pipefail
        RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
        error() { echo -e "''${RED}[ERROR]''${NC} $*" >&2; }
        success() { echo -e "''${GREEN}[SUCCESS]''${NC} $*"; }
        info() { echo -e "''${YELLOW}[INFO]''${NC} $*"; }
        if [ "$EUID" -ne 0 ]; then error "This script must be run as root"; exit 1; fi
        if [ ! -e /dev/tpmrm0 ] && [ ! -e /dev/tpm0 ]; then error "No TPM device found."; exit 1; fi
        info "TPM device found"
        LUKS_DEVICES=(${lib.concatStringsSep " " (lib.mapAttrsToList (_: cfg: cfg.devicePath) config.custom.boot.luksPartitions)})
        if [ ''${#LUKS_DEVICES[@]} -eq 0 ]; then error "No LUKS devices configured"; exit 1; fi
        info "Found ''${#LUKS_DEVICES[@]} LUKS device(s)"; info "Using PCRs 0 (firmware) and 7 (Secure Boot state)"
        for DEVICE in "''${LUKS_DEVICES[@]}"; do
          info "Processing: $DEVICE"
          if [ ! -e "$DEVICE" ]; then error "Device $DEVICE not found"; continue; fi
          if ! cryptsetup isLuks "$DEVICE" 2>/dev/null; then error "$DEVICE is not a LUKS device"; continue; fi
          if systemd-cryptenroll "$DEVICE" 2>/dev/null | grep -q "tpm2"; then
            info "TPM2 token already exists for $DEVICE"; read -p "Remove and re-enroll? (y/N): " -n 1 -r; echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then info "Removing existing TPM2 tokens..."; systemd-cryptenroll "$DEVICE" --wipe-slot=tpm2 2>/dev/null || true;
            else continue; fi
          fi
          info "Enrolling TPM2 for $DEVICE"; info "You will be prompted for your LUKS passphrase"
          if systemd-cryptenroll "$DEVICE" --tpm2-device=auto --tpm2-pcrs=0+7; then
            success "TPM2 enrolled for $DEVICE"
            if systemd-cryptenroll "$DEVICE" 2>/dev/null | grep -q "tpm2"; then success "Enrollment verified"; else error "Verification failed"; fi
          else error "Enrollment failed for $DEVICE"; fi; echo
        done
        success "Complete! Reboot to test TPM unlock"; info "Your passphrase is still available as backup"
      '')
    ];

    boot = {
      loader = {
        systemd-boot = {
          enable = true;
          configurationLimit = 10;
        };
        efi.canTouchEfiVariables = true;
      };
      initrd = {
        systemd = {enable = true;};
        availableKernelModules = ["tpm_crb" "tpm_tis"];
        luks.devices =
          lib.mapAttrs'
          (
            _: partitionCfg:
              lib.nameValuePair partitionCfg.luksName {
                device = partitionCfg.devicePath;
                inherit (partitionCfg) allowDiscards;
                crypttabExtraOpts = ["tpm2-device=auto" "tpm2-pcrs=0+7" "tries=1"];
              }
          )
          config.custom.boot.luksPartitions;
      };
    };

    security.tpm2 = {
      enable = true;
      pkcs11.enable = true;
      tctiEnvironment.enable = true;
    };

    boot.initrd.systemd.services."systemd-cryptsetup@".serviceConfig = {
      Environment = "SYSTEMD_CRYPTSETUP_USE_TOKEN_MODULE=tpm2";
    };

    services.xserver.videoDrivers = ["modesetting"];

    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver
        vpl-gpu-rt
      ];
    };

    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "iHD";
    };
  };
}
