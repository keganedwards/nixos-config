{
  config,
  pkgs,
  lib,
  ...
}: let
  cryptenrollScript = pkgs.writeShellScript "cryptenroll-tpm" ''
    #!/usr/bin/env bash
    set -euo pipefail

    echo "Starting TPM2 enrollment process..."

    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
      echo "This script must be run as root"
      exit 1
    fi

    # Find the LUKS device
    LUKS_DEVICE=""

    # Try common device paths
    for dev in /dev/nvme0n1p2 /dev/sda2 /dev/vda2; do
      if [ -e "$dev" ] && cryptsetup isLuks "$dev" 2>/dev/null; then
        LUKS_DEVICE="$dev"
        break
      fi
    done

    # If not found, try to detect from current mounts
    if [ -z "$LUKS_DEVICE" ]; then
      # Find the device backing the root filesystem
      ROOT_DEV=$(findmnt -n -o SOURCE /)
      if [[ "$ROOT_DEV" == /dev/mapper/* ]]; then
        # Get the underlying device
        MAPPER_NAME="''${ROOT_DEV##*/}"
        LUKS_DEVICE=$(cryptsetup status "$MAPPER_NAME" 2>/dev/null | grep "device:" | awk '{print $2}')
      fi
    fi

    if [ -z "$LUKS_DEVICE" ] || [ ! -e "$LUKS_DEVICE" ]; then
      echo "Could not find LUKS device. Please specify it manually."
      echo "Usage: $0 [device]"
      echo "Example: $0 /dev/nvme0n1p2"
      exit 1
    fi

    echo "Found LUKS device: $LUKS_DEVICE"

    # Check if TPM2 is available
    if ! [ -e /dev/tpm0 ] && ! [ -e /dev/tpmrm0 ]; then
      echo "No TPM device found"
      exit 1
    fi

    # Check if systemd-cryptenroll is available
    if ! command -v systemd-cryptenroll &> /dev/null; then
      echo "systemd-cryptenroll not found"
      exit 1
    fi

    # Check current enrollment status
    echo "Current enrollments:"
    systemd-cryptenroll "$LUKS_DEVICE" || true

    # Remove existing TPM2 enrollments to avoid conflicts
    echo "Removing any existing TPM2 enrollments..."
    for slot in $(system-cryptenroll "$LUKS_DEVICE" | grep tpm2 | awk '{print $1}' | tr -d ':'); do
      echo "Removing TPM2 enrollment in slot $slot"
      systemd-cryptenroll "$LUKS_DEVICE" --wipe-slot="$slot"
    done

    # Enroll with TPM2
    echo "Enrolling TPM2..."
    echo "You will be prompted for your LUKS password:"

    # Use PCR 7 (Secure Boot state) by default, can be customized
    # Add --tpm2-with-pin=yes if you want PIN + TPM
    if systemd-cryptenroll \
      --tpm2-device=auto \
      --tpm2-pcrs=7 \
      "$LUKS_DEVICE"; then
      echo "TPM2 enrollment successful!"

      # Verify enrollment
      echo ""
      echo "Updated enrollments:"
      systemd-cryptenroll "$LUKS_DEVICE"

      echo ""
      echo "TPM2 enrollment complete. Your disk can now be unlocked with the TPM."
      echo "Make sure your NixOS configuration includes:"
      echo '  boot.initrd.systemd.enable = true;'
      echo '  boot.initrd.luks.devices.<name>.crypttabExtraOpts = [ "tpm2-device=auto" ];'
    else
      echo "TPM2 enrollment failed!"
      exit 1
    fi
  '';
in {
  # Include the script in system packages
  environment.systemPackages = [
    cryptenrollScript
    pkgs.systemd # for systemd-cryptenroll
    pkgs.tpm2-tools
  ];

  # Enable TPM2 support
  security.tpm2 = {
    enable = true;
    pkcs11.enable = true;
    tctiEnvironment.enable = true;
  };

  # Ensure TPM2 is available in initrd if using systemd-based initrd
  boot.initrd.availableKernelModules = ["tpm_tis" "tpm_crb"];

  # Add systemd-cryptenroll to initrd if using systemd initrd
  boot.initrd.systemd = {
    extraBin = {
      systemd-cryptenroll = "${pkgs.systemd}/bin/systemd-cryptenroll";
    };
  };
}
