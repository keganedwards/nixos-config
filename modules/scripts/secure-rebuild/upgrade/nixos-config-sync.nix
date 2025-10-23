{
  pkgs,
  config,
  username,
  fullName,
  email,
  flakeDir,
  ...
}: let
  helpers = import ./helpers.nix {
    inherit pkgs config username fullName email;
  };

  configSyncWorker = pkgs.writeShellScript "nixos-config-sync-worker" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    ${helpers.loggingHelpers}

    # Status file for notifications
    STATUS_FILE="/var/lib/nixos-config-sync/last-status"
    mkdir -p "$(dirname "$STATUS_FILE")"

    write_status() {
      echo "$1" > "$STATUS_FILE"
    }

    log_info "NixOS Config Sync Service Starting"

    cd ${flakeDir} || {
      log_error "Failed to change directory to ${flakeDir}"
      write_status "error:cd_failed"
      exit 1
    }

    GIT_CMD="${pkgs.git}/bin/git -c safe.directory=${flakeDir}"

    log_info "Checking repository status..."
    if ! runuser -u ${username} -- $GIT_CMD diff --quiet HEAD --; then
      log_warning "Repository has uncommitted changes. Stopping sync."
      write_status "warn:dirty_repo"
      exit 0
    fi

    log_info "Fetching from remote..."
    if ! ${helpers.gitSshHelper} fetch "${flakeDir}" origin; then
      log_error "Failed to fetch from remote"
      write_status "error:fetch_failed"
      exit 1
    fi

    LOCAL=$(runuser -u ${username} -- $GIT_CMD rev-parse HEAD)
    REMOTE=$(runuser -u ${username} -- $GIT_CMD rev-parse origin/main)

    if [ "$LOCAL" = "$REMOTE" ]; then
      log_success "Repository is up to date"
      write_status "success:up_to_date"
      exit 0
    fi

    # Check if we can fast-forward
    MERGE_BASE=$(runuser -u ${username} -- $GIT_CMD merge-base HEAD origin/main)

    if [ "$MERGE_BASE" != "$LOCAL" ]; then
      log_error "Cannot fast-forward: local branch has diverged from remote"
      log_error "Local:  $LOCAL"
      log_error "Remote: $REMOTE"
      log_error "Base:   $MERGE_BASE"
      write_status "error:diverged"
      exit 1
    fi

    log_info "Fast-forwarding to origin/main..."
    if ! runuser -u ${username} -- $GIT_CMD merge --ff-only origin/main; then
      log_error "Fast-forward merge failed"
      write_status "error:merge_failed"
      exit 1
    fi

    NEW_HASH=$(runuser -u ${username} -- $GIT_CMD rev-parse HEAD)
    log_success "Successfully synced to: ''${NEW_HASH:0:7}"
    write_status "success:synced:''${NEW_HASH:0:7}"
  '';

  notifyConfigSyncResult = pkgs.writeShellScript "notify-config-sync-result" ''
    #!${pkgs.bash}/bin/bash
    STATUS_FILE="/var/lib/nixos-config-sync/last-status"

    if [ ! -f "$STATUS_FILE" ]; then
      exit 0
    fi

    STATUS=$(cat "$STATUS_FILE")

    for i in {1..30}; do
      if [ -n "$WAYLAND_DISPLAY" ] || [ -n "$DISPLAY" ]; then
        break
      fi
      sleep 1
    done

    if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ]; then
      exit 0
    fi

    case "$STATUS" in
      success:up_to_date)
        # Don't notify for up-to-date - too noisy
        ;;
      success:synced:*)
        HASH=''${STATUS##*:}
        ${pkgs.libnotify}/bin/notify-send -u normal -t 8000 \
          "📥 Config Synced" \
          "NixOS configuration updated to $HASH"
        ;;
      warn:dirty_repo)
        ${pkgs.libnotify}/bin/notify-send -u normal -t 10000 \
          "⚠️ Config Sync Skipped" \
          "Repository has uncommitted changes. Sync skipped."
        ;;
      error:diverged)
        ${pkgs.libnotify}/bin/notify-send -u critical -t 0 \
          "⚠️ Config Sync Failed: Diverged" \
          "Local and remote branches have diverged. Manual merge required."
        ;;
      error:fetch_failed)
        ${pkgs.libnotify}/bin/notify-send -u critical -t 10000 \
          "⚠️ Config Sync Failed" \
          "Failed to fetch from remote repository. Check network connection."
        ;;
      error:merge_failed)
        ${pkgs.libnotify}/bin/notify-send -u critical -t 0 \
          "⚠️ Config Sync Failed: Merge Error" \
          "Failed to merge remote changes. Manual intervention required."
        ;;
      error:*)
        ${pkgs.libnotify}/bin/notify-send -u critical -t 10000 \
          "⚠️ Config Sync Error" \
          "An error occurred during config sync. Check logs."
        ;;
    esac

    rm -f "$STATUS_FILE"
  '';
in {
  systemd = {
    services."nixos-config-sync" = {
      description = "Sync NixOS configuration from remote repository";
      wants = ["network-online.target"];
      after = ["network-online.target"];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${configSyncWorker}";
        User = "root";
        Group = "root";
        Environment = "PATH=${pkgs.git}/bin:${pkgs.openssh}/bin:${pkgs.coreutils}/bin:${pkgs.sshpass}/bin:${pkgs.expect}/bin:/run/current-system/sw/bin";

        # Graceful failure
        SuccessExitStatus = "0 1";
        StandardOutput = "journal";
        StandardError = "journal";
      };

      # Don't restart on failure - just log and notify
      restartIfChanged = false;
      unitConfig = {
        StartLimitBurst = 3;
        StartLimitIntervalSec = 300;
      };
    };

    timers."nixos-config-sync" = {
      description = "Timer for NixOS config sync";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "30min";
        Unit = "nixos-config-sync.service";
      };
    };

    user.services."config-sync-notifier" = {
      description = "Notify user of config sync results";
      wantedBy = ["graphical-session.target"];
      after = ["graphical-session.target"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${notifyConfigSyncResult}";
        RemainAfterExit = false;
      };
    };

    tmpfiles.rules = ["d /var/lib/nixos-config-sync 0755 root root -"];
  };
}
