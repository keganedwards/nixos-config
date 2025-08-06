{
  services.tlp.enable = true; # turns on TLP’s systemd service
  services.tlp.settings = {
    CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
    CPU_SCALING_GOVERNOR_ON_AC = "performance";
    START_CHARGE_THRESH_BAT0 = 40; # optional battery‑health caps
    STOP_CHARGE_THRESH_BAT0 = 80;
  };
}
