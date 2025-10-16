{
  pkgs,
  loginManagerConstants,
  ...
}: {
  services.displayManager.${loginManagerConstants.name} = {
    enable = true;
    wayland.enable = true;
    package = pkgs.kdePackages.${loginManagerConstants.name};
  };
}
