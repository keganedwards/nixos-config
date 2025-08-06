# File: modules/home-manager/scripts/shutdown-manager.nix
{pkgs, ...}: {
  home.packages = [
    (pkgs.writeShellScriptBin "shutdown-manager" ''
      #!${pkgs.bash}/bin/bash
      set -eu

      # Colors for output
      RED='\033[0;31m'
      GREEN='\033[0;32m'
      YELLOW='\033[1;33m'
      BLUE='\033[0;34m'
      NC='\033[0m' # No Color

      log() {
        echo -e "''${BLUE}[$(date '+%H:%M:%S')]''${NC} $1"
      }

      error() {
        echo -e "''${RED}[ERROR]''${NC} $1" >&2
      }

      success() {
        echo -e "''${GREEN}[SUCCESS]''${NC} $1"
      }

      warn() {
        echo -e "''${YELLOW}[WARNING]''${NC} $1"
      }

      # Function to clean up Brave browser
      cleanup_brave() {
        log "Cleaning up Brave browser..."

        # Kill Brave processes gracefully
        if pgrep -f "flatpak.*brave" > /dev/null; then
          log "Terminating Brave processes..."
          pkill -TERM -f "flatpak.*brave" || true
          sleep 3

          # Force kill if still running
          if pgrep -f "flatpak.*brave" > /dev/null; then
            warn "Force killing remaining Brave processes..."
            pkill -KILL -f "flatpak.*brave" || true
          fi
        fi

        # Clean up lock files
        BRAVE_CONFIG_DIR="$HOME/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser"

        if [ -d "$BRAVE_CONFIG_DIR" ]; then
          log "Removing Brave lock files..."
          find "$BRAVE_CONFIG_DIR" -name "lockfile" -delete 2>/dev/null || true
          find "$BRAVE_CONFIG_DIR" -name "Singleton*" -delete 2>/dev/null || true

          # Remove the "Brave didn't shut down properly" flag
          rm -f "$BRAVE_CONFIG_DIR/Default/Preferences.backup" 2>/dev/null || true

          # Modify preferences to indicate clean shutdown
          PREFS_FILE="$BRAVE_CONFIG_DIR/Default/Preferences"
          if [ -f "$PREFS_FILE" ]; then
            # Use jq if available, otherwise use sed
            if command -v jq > /dev/null; then
              jq '.profile.exit_type = "Normal" | .profile.exited_cleanly = true' "$PREFS_FILE" > "$PREFS_FILE.tmp" && mv "$PREFS_FILE.tmp" "$PREFS_FILE" 2>/dev/null || true
            else
              sed -i 's/"exited_cleanly":false/"exited_cleanly":true/g' "$PREFS_FILE" 2>/dev/null || true
              sed -i 's/"exit_type":"[^"]*"/"exit_type":"Normal"/g' "$PREFS_FILE" 2>/dev/null || true
            fi
          fi

          success "Brave cleanup completed"
        else
          warn "Brave config directory not found"
        fi
      }

      # Function to handle system updates with interruption capability
      handle_system_update() {
        log "Starting system update process..."
        log "Press Ctrl+D to skip update and continue with shutdown"

        # Create a temporary script for the update process
        UPDATE_SCRIPT=$(mktemp)
        cat > "$UPDATE_SCRIPT" << 'EOF'
      #!/bin/bash
      echo "Running nixos-upgrade.service..."
      systemctl restart nixos-upgrade.service

      # Wait for the service to complete or fail
      while systemctl is-active --quiet nixos-upgrade.service; do
        sleep 2
        printf "."
      done
      echo ""

      if systemctl is-failed --quiet nixos-upgrade.service; then
        echo "Update service failed or was interrupted"
        exit 1
      else
        echo "Update completed successfully"
        exit 0
      fi
      EOF
        chmod +x "$UPDATE_SCRIPT"

        # Run the update with timeout and interrupt handling
        if timeout 300 bash -c "
          trap 'echo; echo \"Update interrupted by user\"; exit 130' INT
          exec $UPDATE_SCRIPT
        "; then
          success "System update completed"
        else
          case $? in
            124) warn "System update timed out (5 minutes)" ;;
            130) warn "System update interrupted by user" ;;
            *) warn "System update failed or was skipped" ;;
          esac
        fi

        rm -f "$UPDATE_SCRIPT"
      }

      # Function to show interactive prompt for update
      prompt_for_update() {
        echo
        echo -e "''${YELLOW}System Update Options:''${NC}"
        echo "1) Run system update before shutdown"
        echo "2) Skip update and shutdown immediately"
        echo "3) Cancel shutdown"
        echo

        # Use timeout for the read to avoid hanging
        if read -t 10 -p "Choose option (1-3, default: 2 after 10s): " choice; then
          case $choice in
            1) return 0 ;; # Run update
            2) return 1 ;; # Skip update
            3) exit 0 ;;   # Cancel
            *) return 1 ;; # Default: skip
          esac
        else
          echo
          warn "No input received, skipping update"
          return 1
        fi
      }

      # Main execution
      main() {
        log "Starting shutdown manager..."

        # Always clean up Brave
        cleanup_brave

        # Handle system update based on argument or prompt
        case "''${1:-prompt}" in
          --update|-u)
            handle_system_update
            ;;
          --no-update|-n)
            log "Skipping system update as requested"
            ;;
          --force|-f)
            log "Force mode: cleaning up and exiting immediately"
            ;;
          *)
            if prompt_for_update; then
              handle_system_update
            fi
            ;;
        esac

        success "Shutdown manager completed successfully"
      }

      # Handle script interruption
      trap 'echo; warn "Shutdown manager interrupted"; exit 130' INT TERM

      main "$@"
    '')
  ];
}
