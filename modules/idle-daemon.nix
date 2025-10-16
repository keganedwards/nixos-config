{
  pkgs,
  lib,
  username,
  lockscreenConstants,
  windowManagerConstants,
  faillock,
  ...
}: let
  # Variable from idle-daemon.nix
  displayOff = "${windowManagerConstants.msg} action power-off-monitors";
  displayOn = "${windowManagerConstants.msg} action power-on-monitors";

  # Variable from the second file
  lockscreenCmd = pkgs.writeShellScriptBin "lockscreen" ''
    exec ${pkgs.${lockscreenConstants.name}}/bin/${lockscreenConstants.name}
  '';
in {
  # From the second file
  environment.systemPackages = [
    lockscreenCmd
    pkgs.${lockscreenConstants.name}
  ];

  # Merged home-manager configuration
  home-manager.users.${username} = {
    # From idle-daemon.nix: swayidle configuration
    services.swayidle = {
      enable = true;
      systemdTarget = "graphical-session.target";

      timeouts = [
        {
          timeout = 240; # 4 minutes
          command = "${pkgs.libnotify}/bin/notify-send 'Idle Warning' 'Locking in 1 minute' -t 5000";
        }
        {
          timeout = 300; # 5 minutes
          command = "lockscreen";
        }
        {
          timeout = 420; # 7 minutes
          command = displayOff;
          resumeCommand = displayOn;
        }
        {
          timeout = 900; # 15 minutes
          command = "${pkgs.systemd}/bin/systemctl suspend";
        }
      ];

      events = [
        {
          event = "before-sleep";
          command = "lockscreen";
        }
        {
          event = "after-resume";
          command = displayOn;
        }
        {
          event = "lock";
          command = "lockscreen";
        }
      ];
    };

    # From the second file: lockscreen configuration
    catppuccin.${lockscreenConstants.name}.enable = lib.mkForce false;

    programs.${lockscreenConstants.name} = {
      enable = true;
      settings = {
        general.hide_cursor = true;

        background = [
          {
            monitor = "";
            path = "$HOME/.local/share/wallpapers/Bing/lockscreen.jpg";
          }
        ];

        input-field = [
          {
            monitor = "";
            size = "200, 50";
            outline_thickness = 3;
            outer_color = "rgb(151515)";
            inner_color = "rgb(200, 200, 200)";
            font_color = "rgb(10, 10, 10)";
            placeholder_text = "<i>Input Password...</i>";
            hide_input = false;
            fail_color = "rgb(204, 34, 34)";
            fail_text = "<i>$FAIL</i>";
            position = "0, -20";
            halign = "center";
            valign = "center";
          }
        ];

        label = [
          {
            monitor = "";
            # Display the faillock message (e.g., "Account locked for 30 seconds")
            text = ''cmd[update:1000] cat ${faillock.messageFile} 2>/dev/null || echo ""'';
            color = "rgba(200, 200, 200, 1.0)";
            font_size = 16;
            font_family = "Noto Sans";
            position = "0, 80";
            halign = "center";
            valign = "center";
          }
          {
            monitor = "";
            text = "$TIME";
            color = "rgba(200, 200, 200, 1.0)";
            font_size = 55;
            font_family = "Noto Sans";
            position = "0, 180";
            halign = "center";
            valign = "center";
          }
        ];
      };
    };
  };

  # From the second file
  imports = [
    (windowManagerConstants.setKeybinding "Mod+Shift+X" "lockscreen")
  ];
}
