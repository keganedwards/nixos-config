{
  pkgs,
  username,
  ...
}: {
  programs.sway = {
    enable = true;
    extraPackages = [];
  };

  imports = [
    ./greetd.nix
  ];

  home-manager.users.${username} = {
    imports = [
      ./hm-base.nix
      ./hm-startup.nix
      ./hm-workspaces.nix
      ./hm-logout.nix
      ./hm-lock-screen.nix
      ./hm-sway-config.nix
      ./clipboard-manager.nix
    ];
  };

  # Protect Sway configuration AFTER home-manager fully completes
  systemd.services."protect-sway-config-${username}" = {
    description = "Protect Sway configuration directory";
    # Must run AFTER home-manager completes successfully
    after = ["home-manager-${username}.service"];
    requires = ["home-manager-${username}.service"];
    # Triggered by home-manager completion
    wantedBy = ["home-manager-${username}.service"];

    script = ''
      # Add a delay to ensure all home-manager operations are complete
      sleep 5

      # Check if the directory exists
      if [ ! -d "/home/${username}/.config/sway" ]; then
        echo "Sway config directory doesn't exist, skipping protection"
        exit 0
      fi

      # Resolve the symlink if the directory itself is a symlink
      if [ -L "/home/${username}/.config/sway" ]; then
        REAL_PATH=$(readlink -f "/home/${username}/.config/sway")
      else
        REAL_PATH="/home/${username}/.config/sway"
      fi

      # Mount the entire directory as read-only
      if ! mountpoint -q "/home/${username}/.config/sway" 2>/dev/null; then
        ${pkgs.util-linux}/bin/mount --bind -o ro "$REAL_PATH" "/home/${username}/.config/sway"
        echo "Protected Sway config directory at /home/${username}/.config/sway"
      else
        echo "Sway config directory already protected"
      fi
    '';

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  # Separate service for boot-time protection
  systemd.services."protect-sway-config-boot-${username}" = {
    description = "Protect Sway configuration on boot";
    after = ["multi-user.target"];
    wantedBy = ["multi-user.target"];

    script = ''
      # Wait longer on boot to ensure everything is settled
      sleep 30

      if [ -d "/home/${username}/.config/sway" ]; then
        if ! mountpoint -q "/home/${username}/.config/sway" 2>/dev/null; then
          if [ -L "/home/${username}/.config/sway" ]; then
            REAL_PATH=$(readlink -f "/home/${username}/.config/sway")
          else
            REAL_PATH="/home/${username}/.config/sway"
          fi
          ${pkgs.util-linux}/bin/mount --bind -o ro "$REAL_PATH" "/home/${username}/.config/sway"
          echo "Protected Sway config directory on boot"
        fi
      fi
    '';

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };
}
