# /modules/security.nix
{
  lib,
  pkgs,
  ...
}: let
  # Maximum password attempts before permanent lockout
  maxAttempts = 10;
in {
  security = {
    apparmor.enable = true;

    sudo-rs = {
      enable = true;
      extraConfig = ''
        Defaults timestamp_timeout=0
        Defaults passwd_tries=${toString maxAttempts}
      '';
    };

    pam = {
      loginLimits = [
        {
          domain = "@users";
          item = "rtprio";
          type = "-";
          value = 1;
        }
      ];

      services.swaylock = {};

      services.sudo.text = lib.mkDefault (lib.mkBefore ''
        auth required pam_faillock.so preauth dir=/var/lib/faillock deny=${toString maxAttempts} unlock_time=0 even_deny_root
        auth sufficient pam_unix.so nullok
        auth [default=ignore] pam_faillock.so authfail dir=/var/lib/faillock deny=${toString maxAttempts} unlock_time=0 even_deny_root
        auth required pam_deny.so
        account required pam_faillock.so dir=/var/lib/faillock
      '');
    };

    rtkit.enable = true;

    tpm2 = {
      enable = true;
      pkcs11.enable = true;
      tctiEnvironment.enable = true;
    };
  };

  # FIX: Combine all systemd configurations into a single block
  systemd = {
    # Watch faillock directory for changes
    paths.sudo-lockout-watch = {
      wantedBy = ["multi-user.target"];
      pathConfig = {
        PathModified = "/var/lib/faillock";
        Unit = "sudo-lockout-check.service";
      };
    };

    # Check for lockouts when faillock directory changes
    services.sudo-lockout-check = {
      description = "Check for sudo lockouts and notify";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "check-lockouts" ''
          #!${pkgs.bash}/bin/bash
          set -x

          echo "=== Lockout check started at $(${pkgs.coreutils}/bin/date) ==="

          ${pkgs.findutils}/bin/find /var/lib/faillock -type f -maxdepth 1 2>/dev/null | while read -r lockfile; do
            USER=$(${pkgs.coreutils}/bin/basename "$lockfile")

            echo "Checking user: $USER"

            # Count failures
            FAILURES=$(${pkgs.linux-pam}/bin/faillock --dir /var/lib/faillock --user "$USER" 2>/dev/null | \
              ${pkgs.gnused}/bin/sed -n '/^[0-9]\{4\}-/p' | \
              ${pkgs.coreutils}/bin/wc -l)

            echo "User $USER has $FAILURES failed attempts"

            if [ "$FAILURES" -ge ${toString maxAttempts} ]; then
              echo "LOCKOUT THRESHOLD REACHED: User $USER locked after $FAILURES attempts"

              USER_ID=$(${pkgs.coreutils}/bin/id -u "$USER" 2>/dev/null || echo "")
              if [ -n "$USER_ID" ]; then
                ${pkgs.sudo}/bin/sudo -u "$USER" \
                  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" \
                  ${pkgs.libnotify}/bin/notify-send -u critical \
                  "SECURITY LOCKOUT" \
                  "Account permanently locked after ${toString maxAttempts} failed sudo attempts." \
                  2>/dev/null || true
              fi
            fi
          done

          echo "=== Lockout check completed ==="
        '';
      };
    };

    # Ensure directories exist
    tmpfiles.rules = [
      "d /var/lib/faillock 0755 root root -"
      "f /var/log/security-lockouts.log 0600 root root -"
    ];
  };

  environment.systemPackages = with pkgs; [
    libnotify
  ];
}
