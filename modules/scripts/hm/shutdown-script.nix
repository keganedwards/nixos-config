# File: modules/home-manager/scripts/shutdown-script.nix
{pkgs, ...}: {
  home.packages = [
    (pkgs.writeShellScriptBin "robust-shutdown" ''
      #!${pkgs.bash}/bin/bash
      set -euo pipefail

      # Colors for output
      RED='\033[0;31m'
      GREEN='\033[0;32m'
      YELLOW='\033[1;33m'
      BLUE='\033[0;34m'
      NC='\033[0m' # No Color

      # Function to print colored output
      print_status() {
          echo -e "''${BLUE}[SHUTDOWN]''${NC} $1"
      }

      print_success() {
          echo -e "''${GREEN}[SUCCESS]''${NC} $1"
      }

      print_warning() {
          echo -e "''${YELLOW}[WARNING]''${NC} $1"
      }

      print_error() {
          echo -e "''${RED}[ERROR]''${NC} $1"
      }

      # Function to safely close Brave browser
      close_brave() {
          print_status "Checking for Brave browser processes..."

          # Find all Brave processes
          local brave_pids=$(pgrep -f "brave" || true)

          if [ -n "$brave_pids" ]; then
              print_status "Found Brave processes: $brave_pids"

              # Try graceful shutdown first
              print_status "Attempting graceful Brave shutdown..."
              pkill -TERM -f "brave" || true

              # Wait up to 10 seconds for graceful shutdown
              local count=0
              while [ $count -lt 10 ] && pgrep -f "brave" > /dev/null; do
                  sleep 1
                  count=$((count + 1))
                  echo -n "."
              done
              echo

              # Force kill if still running
              if pgrep -f "brave" > /dev/null; then
                  print_warning "Graceful shutdown failed, force killing Brave..."
                  pkill -KILL -f "brave" || true
                  sleep 2
              fi

              # Clean up lock files
              print_status "Cleaning up Brave lock files..."
              local config_dirs=(
                  "$HOME/.config/BraveSoftware/Brave-Browser"
                  "$HOME/.cache/BraveSoftware/Brave-Browser"
              )

              for dir in "''${config_dirs[@]}"; do
                  if [ -d "$dir" ]; then
                      find "$dir" -name "SingletonLock" -delete 2>/dev/null || true
                      find "$dir" -name "SingletonSocket" -delete 2>/dev/null || true
                      find "$dir" -name "SingletonCookie" -delete 2>/dev/null || true
                      find "$dir" -name ".com.google.Chrome.*" -delete 2>/dev/null || true
                  fi
              done

              print_success "Brave browser cleaned up"
          else
              print_status "No Brave processes found"
          fi
      }

      # Function to handle system updates with interruption capability
      handle_system_update() {
          print_status "Checking for system updates..."

          # Create a temporary file to signal interruption
          local interrupt_file="/tmp/shutdown_interrupt_$$"

          # Set up interrupt handler
          trap 'echo -e "\n"; print_warning "Update interrupted by user"; touch "$interrupt_file"; return 0' INT TERM

          # Show user how to interrupt
          print_status "Starting system update (Press Ctrl+C to skip and continue shutdown)..."
          echo -e "''${YELLOW}Press Ctrl+C within 3 seconds to skip update...''${NC}"

          # Give user a chance to interrupt before starting
          local countdown=3
          while [ $countdown -gt 0 ]; do
              echo -n "$countdown "
              sleep 1
              countdown=$((countdown - 1))
              if [ -f "$interrupt_file" ]; then
                  rm -f "$interrupt_file"
                  return 0
              fi
          done
          echo

          # Start the update
          print_status "Running nixos-upgrade service..."
          if systemctl restart nixos-upgrade.service; then
              # Monitor the service
              while systemctl is-active nixos-upgrade.service >/dev/null 2>&1; do
                  if [ -f "$interrupt_file" ]; then
                      print_warning "Stopping nixos-upgrade service..."
                      systemctl stop nixos-upgrade.service || true
                      rm -f "$interrupt_file"
                      return 0
                  fi
                  echo -n "."
                  sleep 2
              done
              echo

              # Check if service completed successfully
              if systemctl is-failed nixos-upgrade.service >/dev/null 2>&1; then
                  print_error "System update failed"
              else
                  print_success "System update completed"
              fi
          else
              print_error "Failed to start nixos-upgrade service"
          fi

          # Cleanup
          rm -f "$interrupt_file"
          trap - INT TERM
      }

      # Function to clean up other applications
      cleanup_applications() {
          print_status "Cleaning up other applications..."

          # Add other applications you want to clean up here
          # Example: Discord, VSCode, etc.
          local apps_to_close=("discord" "code" "firefox")

          for app in "''${apps_to_close[@]}"; do
              if pgrep -f "$app" > /dev/null; then
                  print_status "Closing $app..."
                  pkill -TERM -f "$app" || true
              fi
          done

          # Wait a moment for applications to close
          sleep 2
      }

      # Main execution
      main() {
          print_status "Starting robust shutdown sequence..."

          # Parse command line arguments
          local skip_update=false
          local force_shutdown=false

          while [[ $# -gt 0 ]]; do
              case $1 in
                  --skip-update)
                      skip_update=true
                      shift
                      ;;
                  --force)
                      force_shutdown=true
                      shift
                      ;;
                  --help)
                      echo "Usage: $0 [OPTIONS]"
                      echo "Options:"
                      echo "  --skip-update    Skip system update"
                      echo "  --force         Force shutdown without prompts"
                      echo "  --help          Show this help"
                      exit 0
                      ;;
                  *)
                      print_error "Unknown option: $1"
                      exit 1
                      ;;
              esac
          done

          # Step 1: Close Brave browser properly
          close_brave

          # Step 2: Clean up other applications
          cleanup_applications

          # Step 3: Handle system updates (unless skipped)
          if [ "$skip_update" = false ]; then
              handle_system_update
          else
              print_status "Skipping system update as requested"
          fi

          # Step 4: Final cleanup
          print_status "Performing final cleanup..."
          sync  # Ensure all data is written to disk

          print_success "Shutdown preparation complete!"

          # Optional: Actually trigger shutdown
          if [ "$force_shutdown" = true ]; then
              print_status "Initiating system shutdown..."
              systemctl poweroff
          fi
      }

      # Run main function with all arguments
      main "$@"
    '')
  ];
}
