{lib, windowManagerConstants, username, ...}:
lib.mkMerge [
        {        # Mako configuration (as you have it)
  home-manager.users.${username}.services.mako = {
    enable = true;
    settings = {
      anchor = "top-center";
      default-timeout = 0;
    };
  };
}

  (windowManagerConstants.setKeybinding "mod+Shift+z" "exec makoctl dismiss --all")
]



