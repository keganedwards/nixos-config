# nixos-config/hosts/laptop/system/power-management.nix
{
  services = {
    # 1. Configure UPower to monitor battery levels and properties.
    # This is necessary for responding to low/critical battery events.
    upower = {
      enable = true;
      # 3. Configure behavior for critical battery levels.
      # This is the most important part for data and battery safety.
      criticalPowerAction = "Hibernate";
    };

    # 2. Configure suspend-then-hibernate for idle timeouts.
    # This combines the speed of suspend with the safety of hibernate for long idle periods.
    logind.extraConfig = ''
      # When `systemctl suspend-then-hibernate` is called (e.g., by swayidle),
      # the system will suspend normally, but will automatically wake and
      # hibernate after being suspended for 2 hours.
      HibernateDelaySec=2h
    '';
  };
}
