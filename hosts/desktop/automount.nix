_: {
  fileSystems."/mnt/external" = {
    device = "/dev/disk/by-uuid/6c2ddde2-791e-4432-a59a-9308c8833c3f";
    fsType = "auto"; # or your specific filesystem type
    options = ["noauto" "noatime" "nofail" "user" "rw" "x-systemd.automount"];
  };
}
