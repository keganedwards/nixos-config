{pkgs, ...}: {
  # Add gamescope to your home packages
  home.packages = with pkgs; [
    gamescope
  ];
}
