# /hosts/laptop/boot.nix
let
  # The NEW, CORRECT values from your fresh install
  laptopRootLuksName = "luks-07a6c997-4559-4fa4-ad16-06912c5b2504";
  laptopRootLuksDevicePath = "/dev/disk/by-uuid/07a6c997-4559-4fa4-ad16-06912c5b2504";
in {
  boot.loader.grub.enable = false;

  swapDevices = [
    {
      device = "/swapfile";
      size = 16;
    }
  ];

  # This block is all you need. Your custom module will read this
  # and generate the correct boot.initrd.luks.devices and boot.initrd.clevis.devices.
  custom.boot.luksPartitions = {
    root = {
      luksName = laptopRootLuksName;
      devicePath = laptopRootLuksDevicePath;
    };
  };
}
