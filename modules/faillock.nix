{
  pkgs,
  username,
  lockscreenConstants,
  loginManagerConstants,
  ...
}: let
  stateDir = "/var/lib/auth-state";

  mkFailureScript = pkgs.writeShellScript "auth-failure-${username}" ''
    USER="${username}"

    echo "[$(date)] Failure script called for $USER" >> ${stateDir}/auth-debug.log

    # Get raw faillock output to debug
    ${pkgs.linux-pam}/bin/faillock --user "$USER" 2>&1 | tee -a ${stateDir}/auth-debug.log

    FAIL_COUNT=$(${pkgs.linux-pam}/bin/faillock --user "$USER" 2>/dev/null | \
     grep -c "^20\d{2}-" || echo "0")

    echo "[$(date)] Failure count: $FAIL_COUNT for $USER" >> ${stateDir}/auth-debug.log

    # GrapheneOS formula
    if [[ $FAIL_COUNT -le 4 ]]; then
      UNLOCK_SECONDS=0
    elif [[ $FAIL_COUNT -eq 5 ]]; then
      UNLOCK_SECONDS=30
    elif [[ $FAIL_COUNT -le 9 ]]; then
      UNLOCK_SECONDS=30
    elif [[ $FAIL_COUNT -le 29 ]]; then
      UNLOCK_SECONDS=$((30 * (FAIL_COUNT - 9)))
    elif [[ $FAIL_COUNT -le 139 ]]; then
      EXP=$(( (FAIL_COUNT - 30) / 10 ))
      UNLOCK_SECONDS=$((30 * (2 ** EXP)))
    else
      UNLOCK_SECONDS=86400
    fi

    echo "[$(date)] Calculated delay: $UNLOCK_SECONDS seconds for $FAIL_COUNT attempts" >> ${stateDir}/auth-debug.log

    if [[ $UNLOCK_SECONDS -gt 0 ]]; then
      LOCK_STATUS=$(${pkgs.shadow}/bin/passwd -S "$USER" 2>/dev/null | ${pkgs.gawk}/bin/awk '{print $2}')

      if [[ "$LOCK_STATUS" != "L" ]]; then
        echo "[$(date)] Locking $USER for $UNLOCK_SECONDS seconds" >> ${stateDir}/auth-debug.log

        ${pkgs.shadow}/bin/usermod -L "$USER" 2>&1 | tee -a ${stateDir}/auth-debug.log

        if [[ $UNLOCK_SECONDS -ge 3600 ]]; then
          TIME_DISPLAY="$((UNLOCK_SECONDS / 3600)) hours"
        elif [[ $UNLOCK_SECONDS -ge 60 ]]; then
          TIME_DISPLAY="$((UNLOCK_SECONDS / 60)) minutes"
        else
          TIME_DISPLAY="$UNLOCK_SECONDS seconds"
        fi

        echo "Account locked: $FAIL_COUNT failures. Wait $TIME_DISPLAY" > "${stateDir}/auth-lock-$USER.txt"

        USER_ID=$(${pkgs.coreutils}/bin/id -u "$USER" 2>/dev/null || echo "")
        if [[ -n "$USER_ID" ]] && [[ -d "/run/user/$USER_ID" ]]; then
          ${pkgs.systemd}/bin/systemd-run --uid="$USER_ID" --pipe -q \
            ${pkgs.libnotify}/bin/notify-send \
            --urgency=critical \
            --app-name="Authentication" \
            "Account Locked" \
            "$FAIL_COUNT failed attempts. Locked for $TIME_DISPLAY" 2>/dev/null || true
        fi

        ${pkgs.systemd}/bin/systemd-run \
          --on-active="$UNLOCK_SECONDS" \
          --unit="auth-unlock-$USER-$(date +%s)" \
          --description="Unlock $USER" \
          --collect \
          /bin/sh -c "${pkgs.shadow}/bin/usermod -U $USER && rm -f ${stateDir}/auth-lock-$USER.txt && echo '[$(date)] Auto-unlocked $USER' >> ${stateDir}/auth-debug.log" \
          2>&1 | tee -a ${stateDir}/auth-debug.log
      fi
    elif [[ $FAIL_COUNT -gt 0 ]]; then
      REMAINING=$((5 - FAIL_COUNT))
      MSG="Warning: $FAIL_COUNT failed attempts. $REMAINING more before first lockout"
      echo "$MSG" > "${stateDir}/auth-lock-$USER.txt"
      echo "[$(date)] $MSG" >> ${stateDir}/auth-debug.log
    fi

    exit 0
  '';

  mkSuccessScript = pkgs.writeShellScript "auth-success-${username}" ''
    USER="${username}"
    echo "[$(date)] Success for $USER - resetting faillock" >> ${stateDir}/auth-debug.log
    ${pkgs.shadow}/bin/usermod -U "$USER" 2>/dev/null || true
    ${pkgs.linux-pam}/bin/faillock --user "$USER" --reset
    rm -f "${stateDir}/auth-lock-$USER.txt"
    ${pkgs.systemd}/bin/systemctl stop "auth-unlock-$USER-*" 2>/dev/null || true
    exit 0
  '';

  pamConfig = {
    text = ''
      # IMPORTANT: deny=0 means no limit on failures before deny
      auth required pam_faillock.so preauth silent deny=0
      auth sufficient pam_unix.so nullok try_first_pass
      auth required pam_faillock.so authfail deny=0
      auth optional pam_exec.so seteuid ${mkFailureScript}
      auth requisite pam_deny.so
      auth optional pam_exec.so seteuid ${mkSuccessScript}
      account required pam_unix.so
      password required pam_unix.so nullok sha512
      session required pam_unix.so
    '';
  };
in {
  # Create faillock config to ensure no built-in limits
  environment.etc."security/faillock.conf".text = ''
    # No automatic deny - we handle it ourselves
    deny = 0
    # Don't unlock automatically
    unlock_time = 0
    # No root exemption
    even_deny_root
    # Keep entries for a long time
    fail_interval = 86400
  '';

  systemd.tmpfiles.rules = [
    "d /run/faillock 0755 root root -"
    "d ${stateDir} 0755 root root -"
    "f ${stateDir}/auth-debug.log 0666 root root -"
  ];

  systemd.services.faillock-init = {
    description = "Initialize faillock directory";
    wantedBy = ["sysinit.target"];
    before = ["systemd-logind.service" "display-manager.service"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.coreutils}/bin/mkdir -p /run/faillock ${stateDir}";
      RemainAfterExit = true;
    };
  };

  security.pam.services = {
    sudo = pamConfig;
    ${loginManagerConstants.name} = pamConfig;
    ${lockscreenConstants.name} = pamConfig;
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "check-auth-status" ''
       USER="${username}"
       echo "=== Account Status ==="
       STATUS=$(${pkgs.shadow}/bin/passwd -S "$USER" 2>/dev/null)
       echo "$STATUS"
      echo "$STATUS" | grep -q " L " && echo ">> LOCKED <<" || echo ">> UNLOCKED <<"

       echo ""
       echo "=== Failure Count ==="
       COUNT=$(${pkgs.linux-pam}/bin/faillock --user "$USER" 2>/dev/null | \
         grep -c "^20\d{2}-" || echo "0")
       echo "Count: $COUNT"

       echo ""
       echo "=== Raw Faillock Output ==="
       ${pkgs.linux-pam}/bin/faillock --user "$USER" 2>/dev/null | head -10

       echo ""
       echo "=== Message ==="
       cat ${stateDir}/auth-lock-$USER.txt 2>/dev/null || echo "None"

       echo ""
       echo "=== Debug Log (last 15) ==="
       tail -15 ${stateDir}/auth-debug.log 2>/dev/null
    '')

    (pkgs.writeShellScriptBin "reset-auth-lock" ''
      if [[ $EUID -ne 0 ]]; then
        echo "Must run as root"
        exit 1
      fi

      ${pkgs.shadow}/bin/usermod -U "${username}" 2>&1
      ${pkgs.linux-pam}/bin/faillock --user "${username}" --reset
      rm -f ${stateDir}/auth-lock-${username}.txt
      ${pkgs.systemd}/bin/systemctl stop "auth-unlock-${username}-*" 2>/dev/null || true
      echo "Reset complete"
    '')

    pkgs.libnotify
    pkgs.ripgrep
  ];

  _module.args.faillock = {
    inherit stateDir;
    messageFile = "${stateDir}/auth-lock-${username}.txt";
  };
}
