let
  # --- Desktop Root LUKS Partition ---
  desktopRootLuksName = "luks-46f2b2ad-1ea0-48be-979f-ac3bf337c2e5";
  desktopRootLuksDevicePath = "/dev/disk/by-uuid/46f2b2ad-1ea0-48be-979f-ac3bf337c2e5";

  desktopSwapLuksName = "luks-092efea7-4233-4f19-ab84-e5a1e82d8900";
  desktopSwapLuksDevicePath = "/dev/disk/by-uuid/092efea7-4233-4f19-ab84-e5a1e82d8900";
in {
  custom.boot.luksPartitions = {
    root = {
      luksName = desktopRootLuksName;
      devicePath = desktopRootLuksDevicePath;
    };
    swap = {
      luksName = desktopSwapLuksName;
      devicePath = desktopSwapLuksDevicePath;
    };
  };
}
