{
  lib,
  pkgs,
  username,
  ...
}: {
  security = {
    apparmor.enable = true;

    sudo-rs = {
      enable = true;
      extraConfig = ''
        Defaults timestamp_timeout=0
        Defaults passwd_tries=5
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

      # Faillock just locks for 24 hours - our service will unlock progressively
      services.swaylock = {
        text = ''
          auth required pam_faillock.so preauth dir=/var/lib/faillock deny=5 unlock_time=86400 audit
          auth sufficient pam_unix.so nullok try_first_pass
          auth [default=ignore] pam_faillock.so authfail dir=/var/lib/faillock deny=5 unlock_time=86400 audit
          auth required pam_deny.so
          account required pam_faillock.so dir=/var/lib/faillock
          account required pam_unix.so
          session required pam_unix.so
        '';
      };

      services.sudo.text = lib.mkDefault (lib.mkBefore ''
        auth required pam_faillock.so preauth dir=/var/lib/faillock deny=5 unlock_time=86400 audit
        auth sufficient pam_unix.so nullok
        auth [default=ignore] pam_faillock.so authfail dir=/var/lib/faillock deny=5 unlock_time=86400 audit
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
    services.auth-monitor = {
      description = "Progressive authentication timeout monitor";
      wantedBy = ["multi-user.target"];
      after = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        Restart = "always";
        RestartSec = "5";
        StandardOutput = "journal";
        StandardError = "journal";
        ExecStart = pkgs.writeShellScript "auth-monitor" ''
          #!${pkgs.bash}/bin/bash
          set -euo pipefail

          STATE_DIR="/var/lib/auth-monitor"
          LOG_FILE="/var/log/auth-monitor.log"

          mkdir -p "$STATE_DIR"
          touch "$LOG_FILE"
          chmod 644 "$LOG_FILE"

          log_msg() {
            local msg="[$(${pkgs.coreutils}/bin/date '+%Y-%m-%d %H:%M:%S')] $1"
            echo "$msg" >> "$LOG_FILE"
            echo "$msg" >&2
          }

          get_total_attempts() {
            local user=$1
            local file="$STATE_DIR/$user.attempts"
            if [[ -f "$file" ]]; then
              local value
              value=$(cat "$file" 2>/dev/null | tr -d '[:space:]')
              if [[ -z "$value" ]] || ! [[ "$value" =~ ^[0-9]+$ ]]; then
                echo "0"
              else
                echo "$value"
              fi
            else
              echo "0"
            fi
          }

          set_total_attempts() {
            local user=$1
            local count=$2
            echo "$count" > "$STATE_DIR/$user.attempts"
            chown root:root "$STATE_DIR/$user.attempts"
            chmod 600 "$STATE_DIR/$user.attempts"
            log_msg "Set total attempts for $user to $count"
          }

          calculate_timeout() {
            local attempts=$1
            # No timeout for first 4 attempts
            if [[ "$attempts" -lt 5 ]]; then
              echo "0"
              return
            fi

            # Calculate which set of 5 we're in (0-indexed)
            local tier=$(( (attempts - 1) / 5 ))

            # 30 seconds * 2^tier
            local timeout=$((30 * (1 << tier)))
            echo "$timeout"
          }

          get_faillock_count() {
            local user=$1
            local count=0

            # Get faillock output
            local output
            output=$(${pkgs.linux-pam}/bin/faillock --dir /var/lib/faillock --user "$user" 2>/dev/null || true)

            if [[ -n "$output" ]]; then
              # Count lines that start with a date pattern (YYYY-MM-DD)
              count=$(echo "$output" | ${pkgs.gnugrep}/bin/grep -c '^[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}' || echo "0")
            fi

            # Ensure we return a valid number
            if ! [[ "$count" =~ ^[0-9]+$ ]]; then
              count="0"
            fi

            echo "$count"
          }

          send_notification() {
            local user=$1
            local title=$2
            local message=$3
            local urgency=$4

            log_msg "Sending notification to $user: $title - $message"

            local uid
            uid=$(${pkgs.coreutils}/bin/id -u "$user" 2>/dev/null || echo "")

            if [[ -z "$uid" ]]; then
              log_msg "Could not find UID for user $user"
              return 1
            fi

            # Try to send notification using sudo to run as user
            ${pkgs.systemd}/bin/sudo -u "$user" \
              DISPLAY=:0 \
              DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
              ${pkgs.libnotify}/bin/notify-send -u "$urgency" "$title" "$message" -t 10000 2>/dev/null || {
              log_msg "Failed to send desktop notification, using wall"
              echo "$title: $message" | ${pkgs.util-linux}/bin/wall
            }
          }

          kill_swaylock() {
            local user=$1
            log_msg "Killing swaylock for user $user"
            ${pkgs.procps}/bin/pkill -u "$user" swaylock 2>/dev/null || true
            sleep 0.5
            ${pkgs.procps}/bin/pkill -9 -u "$user" swaylock 2>/dev/null || true
          }

          restart_swaylock() {
            local user=$1
            local uid
            uid=$(${pkgs.coreutils}/bin/id -u "$user" 2>/dev/null || echo "")

            if [[ -z "$uid" ]]; then
              return 1
            fi

            log_msg "Restarting swaylock for user $user"

            ${pkgs.systemd}/bin/sudo -u "$user" \
              WAYLAND_DISPLAY="wayland-1" \
              XDG_RUNTIME_DIR="/run/user/$uid" \
              ${pkgs.swaylock}/bin/swaylock --color 000000 --show-failed-attempts --ignore-empty-password &
          }

          reset_faillock() {
            local user=$1
            ${pkgs.linux-pam}/bin/faillock --dir /var/lib/faillock --user "$user" --reset 2>/dev/null || true
            log_msg "Reset faillock for user $user"
          }

          monitor_user() {
            local user=$1

            # Check if user exists
            if ! ${pkgs.coreutils}/bin/id "$user" &>/dev/null; then
              return
            fi

            local faillock_count
            faillock_count=$(get_faillock_count "$user")

            local total_attempts
            total_attempts=$(get_total_attempts "$user")

            # Track previous faillock count
            local prev_count_file="$STATE_DIR/$user.prev_faillock"
            local prev_count=0
            if [[ -f "$prev_count_file" ]]; then
              prev_count=$(cat "$prev_count_file" 2>/dev/null | tr -d '[:space:]')
              if ! [[ "$prev_count" =~ ^[0-9]+$ ]]; then
                prev_count=0
              fi
            fi

            # Detect successful auth: faillock count went to 0 but we didn't reset it
            local we_reset_file="$STATE_DIR/$user.we_reset"
            if [[ "$faillock_count" -eq 0 ]] && [[ "$prev_count" -gt 0 ]]; then
              if [[ ! -f "$we_reset_file" ]]; then
                # User successfully authenticated - reset our counter
                log_msg "User $user: Successful authentication detected (faillock cleared externally)"
                set_total_attempts "$user" "0"
                rm -f "$STATE_DIR/$user.lockout_start"
                rm -f "$STATE_DIR/$user.last_locked_count"
              else
                # We reset it, clean up flag
                rm -f "$we_reset_file"
              fi
            fi

            # Save current count for next iteration
            echo "$faillock_count" > "$prev_count_file"

            log_msg "User $user: faillock=$faillock_count, total=$total_attempts"

            # If faillock shows 5+ failures, user is locked
            if [[ "$faillock_count" -ge 5 ]]; then
              # Add these failures to our total if not already counted
              local last_locked_file="$STATE_DIR/$user.last_locked_count"
              local last_locked_count=0
              if [[ -f "$last_locked_file" ]]; then
                last_locked_count=$(cat "$last_locked_file" 2>/dev/null | tr -d '[:space:]')
                if ! [[ "$last_locked_count" =~ ^[0-9]+$ ]]; then
                  last_locked_count=0
                fi
              fi

              if [[ "$faillock_count" -gt "$last_locked_count" ]]; then
                # New lockout or additional failures
                local new_failures=$((faillock_count - last_locked_count))
                total_attempts=$((total_attempts + new_failures))
                set_total_attempts "$user" "$total_attempts"
                echo "$faillock_count" > "$last_locked_file"

                log_msg "User $user: Added $new_failures new failures, total now $total_attempts"
              fi

              # Calculate timeout based on total attempts
              local timeout
              timeout=$(calculate_timeout "$total_attempts")

              log_msg "User $user: Locked with $total_attempts total attempts, timeout=$timeout seconds"

              # Check if we're in timeout or should unlock
              local lockout_start_file="$STATE_DIR/$user.lockout_start"

              if [[ ! -f "$lockout_start_file" ]]; then
                # New lockout - start timer
                echo "$(${pkgs.coreutils}/bin/date +%s)" > "$lockout_start_file"

                # Kill swaylock first
                kill_swaylock "$user"

                # Send notification
                send_notification "$user" "Account Locked" \
                  "Too many failed attempts ($total_attempts total). Locked for $timeout seconds." "critical"

                log_msg "User $user: Started lockout timer for $timeout seconds"
              else
                # Check if timeout has expired
                local start_time
                start_time=$(cat "$lockout_start_file" 2>/dev/null | tr -d '[:space:]')
                if ! [[ "$start_time" =~ ^[0-9]+$ ]]; then
                  start_time=$(${pkgs.coreutils}/bin/date +%s)
                  echo "$start_time" > "$lockout_start_file"
                fi

                local current_time
                current_time=$(${pkgs.coreutils}/bin/date +%s)
                local elapsed=$((current_time - start_time))

                if [[ "$elapsed" -ge "$timeout" ]]; then
                  # Timeout expired - unlock
                  log_msg "User $user: Timeout expired after $elapsed seconds, unlocking"

                  # Mark that we're doing the reset
                  touch "$we_reset_file"
                  reset_faillock "$user"
                  rm -f "$lockout_start_file"
                  rm -f "$last_locked_file"

                  # Send unlock notification
                  send_notification "$user" "Account Unlocked" \
                    "You may now attempt authentication (5 attempts before next lockout)." "normal"

                  # Restart swaylock
                  restart_swaylock "$user"
                else
                  local remaining=$((timeout - elapsed))
                  if [[ $((elapsed % 10)) -eq 0 ]]; then
                    log_msg "User $user: Still locked - $remaining seconds remaining of $timeout second timeout"
                  fi
                fi
              fi
            else
              # Not currently locked by faillock
              if [[ -f "$STATE_DIR/$user.lockout_start" ]]; then
                # Was locked but now unlocked (we must have just reset it)
                rm -f "$STATE_DIR/$user.lockout_start"
                rm -f "$STATE_DIR/$user.last_locked_count"
                log_msg "User $user: Cleaned up lockout state files"
              fi
            fi
          }

          log_msg "=== Auth monitor started ==="
          log_msg "Monitoring user: ${username}"

          # Wait a moment for system to be ready
          sleep 2

          # Main monitoring loop
          while true; do
            monitor_user "${username}"
            sleep 5
          done
        '';
      };
    };

    tmpfiles.rules = [
      "d /var/lib/faillock 0700 root root -"
      "d /var/lib/auth-monitor 0700 root root -"
      "f /var/log/auth-monitor.log 0644 root root -"
    ];
  };

  environment.systemPackages = with pkgs; [
    libnotify
    ripgrep
    gnugrep
    util-linux
    procps
    # Block regular users from using faillock
    (pkgs.writeShellScriptBin "faillock" ''
      if [[ $EUID -ne 0 ]]; then
        echo "Permission denied: faillock is restricted to administrators"
        exit 1
      fi
      exec ${pkgs.linux-pam}/bin/faillock "$@"
    '')
  ];
}
