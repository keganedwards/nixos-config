{
  # Mako configuration (as you have it)
  services.mako = {
    enable = true;
    settings = {
      anchor = "top-center";
      default-timeout = 0;
    };
  };

  # Sway configuration
  wayland.windowManager.sway = {
    extraConfig = ''
      bindsym mod4+Mod1+z exec makoctl dismiss --all
    '';
  };
}
