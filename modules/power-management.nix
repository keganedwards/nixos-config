# /modules/power-management.nix
#
# Base power management settings shared by all machines (desktops and laptops).
{
  # 1. Enable UPower for monitoring power sources (battery or UPS).
  services.upower = {
    enable = true;
    criticalPowerAction = "Hibernate";
  };

  # 2. Configure the physical power button to suspend.
  services.logind.settings.Login.HandlePowerKey = "suspend";

  # 3. Enable suspend-then-hibernate for all systems.
  # When suspended, the system will automatically wake and hibernate after 2 hours.
  # - Laptop: Prevents battery drain during long suspends.
  # - Desktop: Saves a small amount of power for long suspends.
  systemd.sleep.extraConfig = ''
    HibernateDelaySec=2h
  '';
}
