{
  pkgs,
  username,
  windowManagerConstants,
  ...
}: let
  lockscreenCmd = pkgs.writeShellScriptBin "lockscreen" ''
    #!${pkgs.bash}/bin/bash
    WALLPAPER="$HOME/.local/share/wallpapers/Bing/lockscreen.jpg"

    if [[ -f "$WALLPAPER" ]]; then
      exec ${pkgs.swaylock}/bin/swaylock \
        --image "$WALLPAPER" \
        --font "Fira Code" \
        --show-failed-attempts \
        --ignore-empty-password
    else
      exec ${pkgs.swaylock}/bin/swaylock \
        --color 000000 \
        --show-failed-attempts \
        --ignore-empty-password
    fi
  '';

  displayOff = "${windowManagerConstants.msg} action power-off-monitors";
  displayOn = "${windowManagerConstants.msg} action power-on-monitors";

  simpleLock = "${pkgs.swaylock}/bin/swaylock --color 000000 --show-failed-attempts --ignore-empty-password";
in {
  # Install lockscreen command system-wide
  environment.systemPackages = [
    lockscreenCmd
  ];

  home-manager.users.${username} = {
    home.packages = with pkgs; [
      swaylock
      swayidle
      libnotify
    ];

    programs.swaylock.enable = true;

    services.swayidle = {
      enable = true;

      timeouts = [
        {
          timeout = 240; # 4 minutes
          command = "${pkgs.libnotify}/bin/notify-send 'Idle Warning' 'Locking in 1 minute' -t 5000";
        }
        {
          timeout = 300; # 5 minutes
          command = "${lockscreenCmd}/bin/lockscreen";
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
          command = "${displayOff}; ${simpleLock}";
        }
        {
          event = "after-resume";
          command = displayOn;
        }
        {
          event = "lock";
          command = "${displayOff}; ${simpleLock}";
        }
        {
          event = "unlock";
          command = displayOn;
        }
      ];
    };
  };

  # Add keybinding for manual lock
  imports = [
    (windowManagerConstants.setKeybinding "Mod+Alt+Shift+L" "${lockscreenCmd}/bin/lockscreen")
  ];
}
