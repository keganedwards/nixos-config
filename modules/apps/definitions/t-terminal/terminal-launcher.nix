# terminal-launcher.nix
{pkgs}:
pkgs.writeShellScriptBin "terminal-launcher" ''
  #!${pkgs.bash}/bin/bash

  # Parse arguments
  TERMINAL_MODE=false
  FILES=()
  APP_ID=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --terminal|-t)
        TERMINAL_MODE=true
        APP_ID="neovide-terminal"
        shift
        ;;
      --editor|-e)
        APP_ID="neovide"
        shift
        ;;
      *)
        FILES+=("$1")
        shift
        ;;
    esac
  done

  # Default app-id based on mode
  if [ -z "$APP_ID" ]; then
    if [ "$TERMINAL_MODE" = true ]; then
      APP_ID="neovide-terminal"
    else
      APP_ID="neovide"
    fi
  fi

  # Server name for this app instance
  SERVER_NAME="/tmp/nvim-$APP_ID"

  # Check if neovide with this app-id is already running
  EXISTING_WINDOW=$(${pkgs.niri}/bin/niri msg --json windows 2>/dev/null | \
    ${pkgs.jq}/bin/jq -r ".[] | select(.\"app-id\" == \"$APP_ID\") | .id" | head -n1)

  if [ -n "$EXISTING_WINDOW" ]; then
    # Focus existing window
    ${pkgs.niri}/bin/niri msg action focus-window --id "$EXISTING_WINDOW"

    # Wait a moment for window to focus
    sleep 0.1

    # Use nvr to open in existing neovide
    if [ "$TERMINAL_MODE" = true ]; then
      # Open terminal in new tab
      ${pkgs.neovim-remote}/bin/nvr --servername "$SERVER_NAME" \
        --remote-send "<cmd>tabnew +terminal<CR>" 2>/dev/null || \
        echo "Failed to connect to existing instance"
    else
      # Open files in new tabs
      if [ ''${#FILES[@]} -gt 0 ]; then
        ${pkgs.neovim-remote}/bin/nvr --servername "$SERVER_NAME" \
          --remote-tab "''${FILES[@]}" 2>/dev/null || \
          echo "Failed to open files in existing instance"
      else
        # Just open a new empty tab
        ${pkgs.neovim-remote}/bin/nvr --servername "$SERVER_NAME" \
          --remote-send "<cmd>tabnew<CR>" 2>/dev/null || \
          echo "Failed to open new tab"
      fi
    fi
  else
    # Launch new neovide instance
    # Don't set NVIM_LISTEN_ADDRESS - let neovide handle it

    if [ "$TERMINAL_MODE" = true ]; then
      # Launch in terminal mode with server
      ${pkgs.neovide}/bin/neovide \
        --wayland_app_id "$APP_ID" \
        --fork \
        -- --listen "$SERVER_NAME" +terminal &
    else
      # Launch with files or empty
      if [ ''${#FILES[@]} -gt 0 ]; then
        ${pkgs.neovide}/bin/neovide \
          --wayland_app_id "$APP_ID" \
          --fork \
          -- --listen "$SERVER_NAME" "''${FILES[@]}" &
      else
        ${pkgs.neovide}/bin/neovide \
          --wayland_app_id "$APP_ID" \
          --fork \
          -- --listen "$SERVER_NAME" &
      fi
    fi
  fi
''
