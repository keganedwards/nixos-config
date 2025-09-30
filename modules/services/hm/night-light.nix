{pkgs, ...}: let
  monthStr = builtins.replaceStrings ["\n"] [""] (builtins.readFile (pkgs.runCommand "current-month" {} "date +%m > $out"));
  dayStr = builtins.replaceStrings ["\n"] [""] (builtins.readFile (pkgs.runCommand "current-day" {} "date +%d > $out"));

  currentMonth = builtins.fromJSON (
    if builtins.substring 0 1 monthStr == "0"
    then builtins.substring 1 1 monthStr
    else monthStr
  );
  currentDay = builtins.fromJSON (
    if builtins.substring 0 1 dayStr == "0"
    then builtins.substring 1 1 dayStr
    else dayStr
  );

  isWinterPeriod = (currentMonth >= 10) || (currentMonth <= 3 && (currentMonth < 3 || currentDay <= 9));

  latitude = "36";
  longitude = "-79";
in {
  services.gammastep = {
    enable = true;
    temperature = {
      night = 1000;
      day = 6500;
    };
    provider = "manual";
    latitude = latitude;
    longitude = longitude;
    settings = {
      general =
        {
          adjustment-method = "wayland";
          brightness-night = "0.1";
        }
        // (
          if isWinterPeriod
          then {
            dawn-time = "06:00-07:00";
            dusk-time = "19:00-19:15";
          }
          else {
          }
        );
    };
  };

  # wluma configuration
  services.wluma = {
    enable = true;
    settings = {
      als.time = {
        thresholds =
          if isWinterPeriod
          then {
            "0" = "night";
            "7" = "day";
            "19" = "night";
          }
          else {
            "0" = "night";
            "7" = "day";
            "sunset" = "night";
          };
      };

      output.backlight = [
        {
          name = "eDP-1";
          path = "/sys/class/backlight/intel_backlight";
          capturer = "wayland";

          predictor.manual = {
            thresholds = {
              night = {
                "0" = 0; # Pure black - no reduction
                "25" = 40; # Dark content - 40% reduction
                "50" = 60; # Medium content - 60% reduction
                "75" = 75; # Bright content - 75% reduction
                "100" = 90; # Pure white - 90% reduction
              };
              day = {
                "0" = 0;
                "25" = 0;
                "50" = 0;
                "75" = 0;
                "100" = 0;
              };
            };
          };
        }
      ];
    };
  };

  # Manual brightness + color temp controls
  home.packages = [
    (pkgs.writeShellScriptBin "brightness-control" ''
      #!/usr/bin/env bash
      case "$1" in
        "low")
          ${pkgs.brightnessctl}/bin/brightnessctl set 5%
          pkill gammastep 2>/dev/null || true
          sleep 0.2
          ${pkgs.gammastep}/bin/gammastep -O 1000 -m wayland &
          ;;
        "medium")
          ${pkgs.brightnessctl}/bin/brightnessctl set 20%
          pkill gammastep 2>/dev/null || true
          sleep 0.2
          ${pkgs.gammastep}/bin/gammastep -O 3000 -m wayland &
          ;;
        "high")
          ${pkgs.brightnessctl}/bin/brightnessctl set 60%
          pkill gammastep 2>/dev/null || true
          ;;
        "auto")
          ${pkgs.brightnessctl}/bin/brightnessctl set 60%
          pkill gammastep 2>/dev/null || true
          sleep 0.5
          systemctl --user restart gammastep
          ;;
      esac
    '')
  ];

  # Shift+F keybindings
  wayland.windowManager.sway.config.keybindings = let
    modifier = "Shift";
  in {
    "${modifier}+F3" = "exec brightness-control low";
    "${modifier}+F4" = "exec brightness-control medium";
    "${modifier}+F5" = "exec brightness-control high";
    "${modifier}+F6" = "exec brightness-control auto";
  };
}
