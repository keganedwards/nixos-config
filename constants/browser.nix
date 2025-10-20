{pkgs}: {
  defaultFlatpakId = "com.brave.Browser";
  defaultWmClass = "brave-browser";
  launchCommand = "${pkgs.flatpak}/bin/flatpak run com.brave.Browser";
}
