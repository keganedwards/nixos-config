{
  pkgs,
  username,
  ...
}: {
  programs.fish.enable = true;

  programs.bash = {
    interactiveShellInit = ''
      if [[ $(${pkgs.procps}/bin/ps --no-header --pid=$PPID --format=comm) != "fish" && -z ''${BASH_EXECUTION_STRING} ]]
      then
        shopt -q login_shell && LOGIN_OPTION='--login' || LOGIN_OPTION=""
        exec ${pkgs.fish}/bin/fish $LOGIN_OPTION
      fi
    '';
  };

  # Protect fish configuration AFTER home-manager fully completes
  systemd.services."protect-fish-config-${username}" = {
    description = "Protect fish configuration files";
    # Must run AFTER home-manager completes successfully
    after = ["home-manager-${username}.service"];
    requires = ["home-manager-${username}.service"]; # Only run if home-manager succeeds
    # Don't be part of the default boot target - triggered by home-manager completion
    wantedBy = ["home-manager-${username}.service"];

    script = ''
      # Add a delay to ensure all home-manager operations are complete
      sleep 5

      # Check if the directory exists and has content
      if [ ! -d "/home/${username}/.config/fish" ] || [ -z "$(ls -A /home/${username}/.config/fish)" ]; then
        echo "Fish config directory doesn't exist or is empty, skipping protection"
        exit 0
      fi

      # Resolve symlinks for individual files/dirs
      for item in config.fish conf.d functions; do
        if [ -e "/home/${username}/.config/fish/$item" ]; then
          if [ -L "/home/${username}/.config/fish/$item" ]; then
            REAL_PATH=$(readlink -f "/home/${username}/.config/fish/$item")
          else
            REAL_PATH="/home/${username}/.config/fish/$item"
          fi

          if ! mountpoint -q "/home/${username}/.config/fish/$item" 2>/dev/null; then
            ${pkgs.util-linux}/bin/mount --bind -o ro "$REAL_PATH" "/home/${username}/.config/fish/$item"
            echo "Protected fish $item"
          fi
        fi
      done
    '';

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  # Run protection on every boot, but only after ensuring home-manager ran first
  systemd.services."protect-fish-config-boot-${username}" = {
    description = "Protect fish configuration on boot";
    after = ["multi-user.target"];
    wantedBy = ["multi-user.target"];

    script = ''
      # Wait longer on boot to ensure everything is settled
      sleep 30

      if [ -d "/home/${username}/.config/fish" ]; then
        for item in config.fish conf.d functions; do
          if [ -e "/home/${username}/.config/fish/$item" ]; then
            if ! mountpoint -q "/home/${username}/.config/fish/$item" 2>/dev/null; then
              if [ -L "/home/${username}/.config/fish/$item" ]; then
                REAL_PATH=$(readlink -f "/home/${username}/.config/fish/$item")
              else
                REAL_PATH="/home/${username}/.config/fish/$item"
              fi
              ${pkgs.util-linux}/bin/mount --bind -o ro "$REAL_PATH" "/home/${username}/.config/fish/$item"
              echo "Protected fish $item on boot"
            fi
          fi
        done
      fi
    '';

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };
}
