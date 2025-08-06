# home-manager-modules/battery-notifier.nix (or wherever you defined it)
{
  pkgs,
  lib,
  ...
}: let
  # Add lib here if not already present
  # Define the battery notifier script using writeShellScriptBin
  batteryNotifier = pkgs.writeShellScriptBin "battery-notifier" ''
    #!${pkgs.bash}/bin/bash

    # Find the first available battery
    # Using full path to commands for extra safety, though adding to PATH should suffice
    _ls="${pkgs.coreutils}/bin/ls"
    _head="${pkgs.coreutils}/bin/head"
    _dirname="${pkgs.coreutils}/bin/dirname"
    _cat="${pkgs.coreutils}/bin/cat"
    _mkdir="${pkgs.coreutils}/bin/mkdir"
    _touch="${pkgs.coreutils}/bin/touch"
    _rm="${pkgs.coreutils}/bin/rm"
    _notify_send="${pkgs.libnotify}/bin/notify-send"


    BATTERY_PATH=$($_ls /sys/class/power_supply/BAT*/capacity 2>/dev/null | $_head -n1)
    if [ -z "$BATTERY_PATH" ]; then
      echo "No battery found"
      exit 1
    fi
    BATTERY_DIR=$($_dirname "$BATTERY_PATH")
    capacity=$($_cat "$BATTERY_PATH")
    status=$($_cat "$BATTERY_DIR/status")

    # Directory to store notification flags in /tmp (cleared on reboot)
    FLAG_DIR="/tmp/battery_flags"
    $_mkdir -p "$FLAG_DIR"

    # Check battery status and send notifications when discharging
    if [ "$status" = "Discharging" ]; then
      if [ "$capacity" -le 5 ] && [ ! -f "$FLAG_DIR/5" ]; then
        $_notify_send -u critical "Battery critically low" "Battery is at $capacity%. Please plug in."
        $_touch "$FLAG_DIR/5"
      elif [ "$capacity" -le 10 ] && [ ! -f "$FLAG_DIR/10" ]; then
        $_notify_send -u critical "Battery very low" "Battery is at $capacity%. Please plug in soon."
        $_touch "$FLAG_DIR/10"
      elif [ "$capacity" -le 20 ] && [ ! -f "$FLAG_DIR/20" ]; then
        $_notify_send "Battery low" "Battery is at $capacity%. Consider plugging in."
        $_touch "$FLAG_DIR/20"
      fi
    else
      # Remove flags when charging or full
      $_rm -f "$FLAG_DIR"/*
    fi
  '';
in {
  # Add the script to the user's packages (ensures availability in interactive shell)
  # This does NOT affect the systemd service environment directly.
  home.packages = [batteryNotifier pkgs.coreutils pkgs.libnotify];

  # Define the systemd service to run the script
  systemd.user.services.battery-notifier = {
    Unit = {
      Description = "Battery level notifier";
    };
    Service = {
      ExecStart = "${batteryNotifier}/bin/battery-notifier";
      # --- FIX: Add required packages to the service's PATH ---
      # Use pkgs.lib.makeBinPath to construct the PATH correctly
      Environment = "PATH=${lib.makeBinPath [pkgs.coreutils pkgs.bash pkgs.libnotify]}";
      # Note: Adding $PATH at the end might be needed if other system things are expected
      # Environment = "PATH=${lib.makeBinPath [ pkgs.coreutils pkgs.bash pkgs.libnotify ]}:$PATH";
    };
  };

  # Define the systemd timer to run the service every 5 minutes
  systemd.user.timers.battery-notifier = {
    Unit = {
      Description = "Run battery notifier every 5 minutes";
    };
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "5min";
    };
    Install = {
      WantedBy = ["timers.target"];
    };
  };
}
