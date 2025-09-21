# /etc/nixos/hosts/desktop/boot/boot.nix
let
  # --- Desktop Root LUKS Partition ---
  desktopRootLuksName = "luks-46f2b2ad-1ea0-48be-979f-ac3bf337c2e5";
  desktopRootLuksDevicePath = "/dev/disk/by-uuid/46f2b2ad-1ea0-48be-979f-ac3bf337c2e5";

  # --- Desktop Swap LUKS Partition ---
  # From lsblk: nvme0n1p3 -> luks-092efea7-4233-4f19-ab84-e5a1e82d8900
  # This is the UUID of the LUKS header on /dev/nvme0n1p3
  desktopSwapLuksName = "luks-092efea7-4233-4f19-ab84-e5a1e82d8900";
  # THIS IS THE CORRECTION: Path to the raw encrypted LUKS partition for swap
  desktopSwapLuksDevicePath = "/dev/disk/by-uuid/092efea7-4233-4f19-ab84-e5a1e82d8900"; # <--- CORRECTED UUID
in {
  custom.boot.luksPartitions = {
    root = {
      luksName = desktopRootLuksName;
      devicePath = desktopRootLuksDevicePath;
    };
    swap = {
      luksName = desktopSwapLuksName;
      devicePath = desktopSwapLuksDevicePath; # Uses the corrected path
    };
  };
}
