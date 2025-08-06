# modules/home-manager/power-management/wlogout.nix
{pkgs, ...}: {
  # ===================================================================
  #  1. wlogout Program Configuration
  # ===================================================================
  programs.wlogout = {
    enable = true;
    layout = [
      {
        label = "lock";
        action = "sway-lock-fancy";
        text = "Lock (L)";
        keybind = "l";
      }
      {
        label = "suspend";
        action = "systemctl suspend";
        text = "Sleep (S)";
        keybind = "s";
      }
      {
        label = "hibernate";
        action = "systemctl hibernate";
        text = "Hibernate (H)";
        keybind = "h";
      }
      {
        label = "logout";
        action = "${pkgs.flatpak}/bin/flatpak kill com.brave.Browser || true; ${pkgs.sway}/bin/swaymsg exit";
        text = "Exit (E)";
        keybind = "e";
      }
      {
        label = "reboot";
        action = "${pkgs.flatpak}/bin/flatpak kill com.brave.Browser || true; upgrade-and-reboot";
        text = "Reboot (R)";
        keybind = "r";
      }
      {
        label = "shutdown";
        action = "${pkgs.flatpak}/bin/flatpak kill com.brave.Browser || true; upgrade-and-shutdown";
        text = "Poweroff (P)";
        keybind = "p";
      }
    ];
  };

  # ===================================================================
  #  2. Sway Keybinding to launch wlogout
  # ===================================================================
  wayland.windowManager.sway.config.keybindings = {
    "mod4+Mod1+p" = "exec wlogout";
  };

  # ===================================================================
  #  3. Sway Window Rules for the upgrade terminal (fullscreen float)
  # ===================================================================
  wayland.windowManager.sway.extraConfig = ''
    # Rule for the upgrade terminal: floating fullscreen
    for_window [app_id="upgrade-terminal"] floating enable, \
      resize set width 100vw height 100vh, \
      move position 0 0
  '';
}
