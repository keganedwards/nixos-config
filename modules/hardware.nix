{pkgs, ...}: {
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        rocmPackages.clr.icd

        # Backup package; used by default so comment out if not being used
        #amdvlk
      ];
      # backup package; remove if not used.
      #extraPackages32 = with pkgs; [driversi686Linux.amdvlk];
    };

    bluetooth = {
      enable = true;
      powerOnBoot = true;
    };
  };
}
