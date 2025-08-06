{
  services = {
    # System and background services
    qemuGuest.enable = true;
    spice-vdagentd.enable = true;
    ollama.enable = true;
    avahi.enable = true;
    geoclue2.enable = true;
    printing.enable = true;

    udisks2.enable = true;
    # Desktop-specific services
    gnome.gnome-keyring.enable = true;
  };
}
