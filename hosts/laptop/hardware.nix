{pkgs, ...}: {
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      # For modern Intel CPU's
      intel-media-driver # Enable Hardware Acceleration
      vpl-gpu-rt # Enable QSV
    ];
    extraPackages32 = with pkgs.pkgsi686Linux; [intel-vaapi-driver];
  };
}
