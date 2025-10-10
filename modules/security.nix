{
  lib,
  pkgs,
  ...
}: let
  timeoutConfig = import ../shared/timeout-delays.nix;
in {
  security = {
    apparmor.enable = true;

    sudo-rs = {
      enable = true;
      extraConfig = ''
        Defaults timestamp_timeout=0
        Defaults passwd_tries=${toString timeoutConfig.firstTimeoutAttempts}
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

      services.swaylock = {
        text = ''
          auth required pam_faillock.so preauth dir=/var/lib/faillock deny=${toString timeoutConfig.firstTimeoutAttempts} unlock_time=30 audit silent
          auth sufficient pam_unix.so nullok try_first_pass
          auth [default=ignore] pam_faillock.so authfail dir=/var/lib/faillock deny=${toString timeoutConfig.firstTimeoutAttempts} unlock_time=30 audit silent
          auth required pam_deny.so
          account required pam_faillock.so dir=/var/lib/faillock
          account required pam_unix.so
          session required pam_unix.so
        '';
      };

      services.sudo.text = lib.mkDefault (lib.mkBefore ''
        auth required pam_faillock.so preauth dir=/var/lib/faillock deny=${toString timeoutConfig.firstTimeoutAttempts} unlock_time=30 audit silent
        auth sufficient pam_unix.so nullok
        auth [default=ignore] pam_faillock.so authfail dir=/var/lib/faillock deny=${toString timeoutConfig.firstTimeoutAttempts} unlock_time=30 audit silent
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

  systemd = {
    # Service to implement GrapheneOS-style progressive unlock times
    services.faillock-cleanup = {
      description = "Reset faillock after GrapheneOS-style delays";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "faillock-cleanup" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          LOG_FILE="/var/log/security-lockouts.log"

          log_message() {
            local msg="[$(${pkgs.coreutils}/bin/date '+%Y-%m-%d %H:%M:%S')] $1"
            echo "$msg" >> "$LOG_FILE"
            echo "$msg"
          }

          # Import the timeout calculation from our shared config
          calculate_timeout_delay() {
            local attempts=$1
            if (( attempts >= 141 )); then
              echo $((24*3600))
            elif (( attempts >= 31 )); then
              local exp=$(( (attempts - 30) / 10 ))
              ${pkgs.bc}/bin/bc -l <<< "30 * (2 ^ $exp)" | ${pkgs.coreutils}/bin/cut -d. -f1
            elif (( attempts >= ${toString timeoutConfig.firstTimeoutAttempts} )); then
              echo 30
            else
              echo 0
            fi
          }

          send_notification() {
            local user=$1
            local message=$2
            local title=$3
            local urgency=$4

            local user_id
            user_id=$(${pkgs.coreutils}/bin/id -u "$user" 2>/dev/null || echo "")

            if [[ -n "$user_id" ]]; then
              # Try multiple methods to send notification
              for session_path in "/run/user/$user_id"/*; do
                if [[ -d "$session_path" ]]; then
                  local display_env="$session_path/bus"
                  if [[ -S "$display_env" ]]; then
                    ${pkgs.systemd}/bin/systemd-run --uid="$user_id" --gid="$(${pkgs.coreutils}/bin/id -g "$user")" \
                      --setenv=DBUS_SESSION_BUS_ADDRESS="unix:path=$display_env" \
                      --setenv=DISPLAY=":0" \
                      ${pkgs.libnotify}/bin/notify-send -u "$urgency" "$title" "$message" -t 10000 2>/dev/null && \
                      log_message "Sent $urgency notification to user $user" && return 0
                  fi
                fi
              done

              # Fallback method
              echo "$title: $message" | ${pkgs.util-linux}/bin/wall 2>/dev/null || true
              log_message "Sent wall message to user $user (notification fallback)"
            fi
          }

          log_message "=== Starting faillock cleanup check ==="

          # Check if faillock directory exists and has files
          if [[ ! -d /var/lib/faillock ]]; then
            log_message "Faillock directory does not exist"
            exit 0
          fi

          ${pkgs.fd}/bin/fd -t f . /var/lib/faillock --max-depth 1 -x basename | while IFS= read -r user; do
            log_message "Checking user: $user"

            # Get failure count from faillock
            faillock_output=$(${pkgs.linux-pam}/bin/faillock --dir /var/lib/faillock --user "$user" 2>/dev/null || echo "")

            if [[ -z "$faillock_output" ]]; then
              log_message "User $user has no faillock data"
              continue
            fi

            failures=$(echo "$faillock_output" | ${pkgs.ripgrep}/bin/rg -c "^When:" || echo "0")

            if [[ "$failures" == "0" ]]; then
              log_message "User $user has no failures recorded"
              continue
            fi

            log_message "User $user has $failures failed attempts"

            if [[ "$failures" -ge ${toString timeoutConfig.firstTimeoutAttempts} ]]; then
              # Calculate delay using shared function
              delay=$(calculate_timeout_delay "$failures")
              log_message "User $user: Calculated delay: $delay seconds for $failures attempts"

              # Send immediate lockout notification
              send_notification "$user" \
                "Too many failed authentication attempts ($failures). Account temporarily locked." \
                "Account Locked" \
                "critical"

              # Get the timestamp of the most recent failure
              last_failure_line=$(echo "$faillock_output" | ${pkgs.ripgrep}/bin/rg "^When:" | ${pkgs.coreutils}/bin/tail -1)

              if [[ -n "$last_failure_line" ]]; then
                timestamp_str=$(echo "$last_failure_line" | ${pkgs.gnused}/bin/sed 's/When: //')
                last_failure_time=$(${pkgs.coreutils}/bin/date -d "$timestamp_str" +%s 2>/dev/null || echo "0")
                current_time=$(${pkgs.coreutils}/bin/date +%s)
                time_elapsed=$((current_time - last_failure_time))

                log_message "User $user: Last failure: $timestamp_str"
                log_message "User $user: Elapsed: $time_elapsed seconds, Required: $delay seconds"

                if [[ "$time_elapsed" -ge "$delay" ]]; then
                  log_message "UNLOCKING: User $user after $time_elapsed seconds"
                  ${pkgs.linux-pam}/bin/faillock --dir /var/lib/faillock --user "$user" --reset

                  # Send unlock notification
                  send_notification "$user" \
                    "Account is now unlocked. You can authenticate again." \
                    "Authentication Unlocked" \
                    "normal"
                else
                  remaining=$((delay - time_elapsed))
                  log_message "User $user still locked: $remaining seconds remaining"
                fi
              else
                log_message "WARNING: Could not parse last failure time for user $user"
              fi
            fi
          done

          log_message "=== Faillock cleanup check completed ==="
        '';
      };
    };

    # Timer to run the cleanup service every 5 seconds for immediate notifications
    timers.faillock-cleanup = {
      description = "Timer for faillock cleanup";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "5s";
        OnUnitActiveSec = "5s";
        Unit = "faillock-cleanup.service";
      };
    };

    tmpfiles.rules = [
      "d /var/lib/faillock 0755 root root -"
      "f /var/log/security-lockouts.log 0644 root root -"
    ];
  };

  environment.systemPackages = with pkgs; [
    libnotify
    fd
    ripgrep
    bc
    util-linux
  ];
}
