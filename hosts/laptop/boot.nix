let
  laptopRootLuksName = "luks-8257f608-7967-4c4d-94f2-e416110d9188";
  laptopRootLuksDevicePath = "/dev/disk/by-uuid/8257f608-7967-4c4d-94f2-e416110d9188";
in {
  swapDevices = [
    {
      device = "/swapfile";
      size = 25600; # Size in MB
    }
  ];

  custom.boot.luksPartitions = {
    root = {
      luksName = laptopRootLuksName;
      devicePath = laptopRootLuksDevicePath;
      allowDiscards = true;
    };
  };
}
