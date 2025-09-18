{
  pkgs,
  username,
  ...
}: let
  braveKillerScript = pkgs.writeShellScript "brave-killer" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    log_info() { echo -e "\e[34m[INFO]\e[0m $1" >&2; }
    log_success() { echo -e "\e[32m[SUCCESS]\e[0m $1" >&2; }

    # Kill Brave using flatpak
    log_info "Attempting to kill Brave browser..."

    # Run as the user, not root
    if ${pkgs.systemd}/bin/runuser -l ${username} -c "${pkgs.flatpak}/bin/flatpak kill com.brave.Browser" 2>/dev/null; then
      log_info "Flatpak kill command sent to Brave"
    else
      log_info "Brave may not be running or already closed"
    fi

    # Poll to check if Brave is actually dead
    MAX_WAIT=30  # 30 seconds max wait
    WAITED=0

    while [ $WAITED -lt $MAX_WAIT ]; do
      # Check if Brave is still running using flatpak ps
      BRAVE_RUNNING=$(${pkgs.systemd}/bin/runuser -l ${username} -c "${pkgs.flatpak}/bin/flatpak ps --columns=application" 2>/dev/null | ${pkgs.ripgrep}/bin/rg "com.brave.Browser" || true)

      if [ -z "$BRAVE_RUNNING" ]; then
        log_success "Brave browser fully terminated"
        exit 0
      fi

      log_info "Brave still running, waiting..."
      sleep 1
      WAITED=$((WAITED + 1))
    done

    # If we get here, force kill any remaining processes
    log_info "Timeout reached, attempting force kill..."

    # Try flatpak kill one more time with force
    ${pkgs.systemd}/bin/runuser -l ${username} -c "${pkgs.flatpak}/bin/flatpak kill com.brave.Browser" 2>/dev/null || true

    # As a last resort, kill any brave processes we can find
    ${pkgs.systemd}/bin/runuser -l ${username} -c "${pkgs.procps}/bin/pkill -9 -f 'com\.brave\.Browser'" 2>/dev/null || true

    sleep 2
    log_success "Brave termination complete"
  '';
in {
  # Create a user service that runs earlier
  systemd.user.services."brave-killer" = {
    description = "Kill Brave browser before shutdown/logout";
    unitConfig = {
      DefaultDependencies = false;
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStop = braveKillerScript;
      RemainAfterExit = true;
      TimeoutStopSec = 35;
      StandardOutput = "journal";
      StandardError = "journal";
    };
    # Start with the session so it can be stopped before session ends
    wantedBy = ["default.target"];
    before = ["graphical-session.target"];
  };

  # Also create a system service that runs before graphical target stops
  systemd.services."brave-killer-system" = {
    description = "Kill Brave browser before system shutdown/reboot (system-level)";
    unitConfig = {
      DefaultDependencies = false;
      Before = ["graphical.target" "multi-user.target"];
      Conflicts = ["shutdown.target" "reboot.target" "halt.target"];
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStop = braveKillerScript;
      RemainAfterExit = true;
      TimeoutStopSec = 35;
      StandardOutput = "journal";
      StandardError = "journal";
    };
    wantedBy = ["graphical.target"];
  };
}
