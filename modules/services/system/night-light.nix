{
  pkgs,
  lib,
  windowManagerConstants,
  username,
  ...
}: let
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
in
  lib.mkMerge [
    {
      home-manager.users.${username} = {
        services.gammastep = {
          enable = true;
          temperature = {
            night = 1000;
            day = 6500;
          };
          provider = "manual";
          inherit latitude longitude;
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
                else {}
              );
          };
        };

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
                      "0" = 0;
                      "25" = 40;
                      "50" = 60;
                      "75" = 75;
                      "100" = 90;
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
      };
    }
    (windowManagerConstants.setKeybinding "Super+Alt+semicolon" "exec brightness-control low")
    (windowManagerConstants.setKeybinding "Super+Alt+apostrophe" "exec brightness-control medium")
    (windowManagerConstants.setKeybinding "Super+Alt+period" "exec brightness-control high")
    (windowManagerConstants.setKeybinding "Super+Alt+backslash" "exec brightness-control auto")
  ]
