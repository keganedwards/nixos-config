{pkgs, ...}: {
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver
        vpl-gpu-rt
      ];
    };

    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
  services.xserver.videoDrivers = ["modesetting"];
}
