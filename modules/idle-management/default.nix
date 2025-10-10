{
  pkgs,
  windowManagerConstants,
  ...
}: let
  lockscreenScript = import ./lockscreen.nix {inherit pkgs;};
  idleConfig = import ./idle-config.nix {
    inherit pkgs windowManagerConstants;
  };
in {
  home.packages = with pkgs; [
    lockscreenScript
    swaylock
    swayidle
    libnotify
  ];

  programs.swaylock.enable = true;

  services.swayidle = idleConfig;
}
