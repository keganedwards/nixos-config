# /modules/home-manager/services/notification-daemon.nix
{
  # Mako configuration (as you have it)
  services.mako = {
    enable = true;
    # package = pkgs.mako; # Good practice to specify the package
    settings = {
      anchor = "top-center";
      default-timeout = 0;
    };
  };

  # Sway configuration
  wayland.windowManager.sway = {
    extraConfig = ''
      bindsym mod4+z exec makoctl dismiss --all
    '';
  };
}
