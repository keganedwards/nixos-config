{pkgs, ...}: {
  hardware = {
    graphics = {
      enable32Bit = true;
      extraPackages = with pkgs; [
        amdvlk
      ];
      # For 32 bit applications
      extraPackages32 = with pkgs; [
        driversi686Linux.amdvlk
      ];
    };
  };
}
