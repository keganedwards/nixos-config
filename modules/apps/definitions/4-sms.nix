{pkgs, ...}: {
  # The actual executable name (must match what’s on $PATH or installed via another module)
  id = "kdeconnect-sms";

  # Sway’s WM_CLASS (what the application reports). Use this to match its window.
  appId = "org.kde.kdeconnect.sms";

  # Your Sway keybinding hint:
  key = "4";

  # If you want it to autostart at a certain priority, keep this:
  autostartPriority = 11;

  # Add kdePackages.kpeople to the list of packages for your user
  home.packages = [
    pkgs.kdePackages.kpeople
  ];
}
