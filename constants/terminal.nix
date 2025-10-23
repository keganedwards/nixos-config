# /constants/terminal.nix - Updated window detection logic
{
  pkgs,
  windowManager,
}: let
  # The actual terminal package
  terminalPackage = pkgs.neovide;
  terminalBin = "${terminalPackage}/bin/neovide";

  # Terminal launcher script with different modes for different app types
  terminalLauncher = pkgs.writeShellScriptBin "terminal-launcher" ''
    #!${pkgs.bash}/bin/bash

    # Debug mode - set to 1 to see what's happening
    DEBUG=0

    debug() {
      [ "$DEBUG" = "1" ] && echo "[DEBUG] $*" >&2
    }

    # Parse arguments
    MODE="generic"  # generic, terminal, editor
    FILES=()
    APP_ID=""
    DESKTOP=""

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --terminal|-t)
          MODE="terminal"
          shift
          ;;
        --editor|-e)
          MODE="editor"
          shift
          ;;
        --generic|-g)
          MODE="generic"
          shift
          ;;
        --app-id)
          APP_ID="$2"
          shift 2
          ;;
        --desktop|-d)
          DESKTOP="$2"
          shift 2
          ;;
        --debug)
          DEBUG=1
          shift
          ;;
        *)
          FILES+=("$1")
          shift
          ;;
      esac
    done

    # Set default app-id based on mode if not provided
    if [ -z "$APP_ID" ]; then
      case "$MODE" in
        terminal)
          APP_ID="${terminalPackage.pname}-terminal"
          ;;
        editor)
          APP_ID="${terminalPackage.pname}"
          ;;
        *)
          APP_ID="${terminalPackage.pname}-generic"
          ;;
      esac
    fi

    debug "MODE: $MODE, APP_ID: $APP_ID, DESKTOP: $DESKTOP"

    # Server name for this app instance
    SERVER_NAME="/tmp/nvim-$APP_ID"

    # Function to switch to desktop
    switch_to_desktop() {
      if [ -n "$DESKTOP" ]; then
        debug "Switching to desktop: ws-$DESKTOP"
        ${windowManager.msg} action focus-workspace "ws-$DESKTOP" 2>/dev/null || true
      fi
    }

    # Function to check if workspace has any windows
    check_workspace_has_window() {
      local desktop="$1"
      local workspace_name="ws-$desktop"

      # Check if the workspace exists and has windows
      local result=$(${windowManager.msg} --json workspaces 2>/dev/null | \
        ${pkgs.jq}/bin/jq -r ".[] | select(.name == \"$workspace_name\") | .active_window_id // \"none\"")

      debug "check_workspace_has_window: workspace=$workspace_name result=$result"

      if [ "$result" != "none" ] && [ -n "$result" ]; then
        # There's a window on this workspace
        echo "yes"
      else
        echo "no"
      fi
    }

    # Function to wait for nvr to be ready
    wait_for_nvr() {
      local attempts=0
      while [ $attempts -lt 10 ]; do
        if ${pkgs.neovim-remote}/bin/nvr --servername "$SERVER_NAME" --remote-send "" 2>/dev/null; then
          debug "nvr ready after $attempts attempts"
          return 0
        fi
        attempts=$((attempts + 1))
        sleep 0.1
      done
      debug "nvr not ready after $attempts attempts"
      return 1
    }

    # Function to check for unsaved work (editor mode)
    check_unsaved_work() {
      local result=$(${pkgs.neovim-remote}/bin/nvr --servername "$SERVER_NAME" \
        --remote-expr 'len(filter(range(1, bufnr("$")), "getbufvar(v:val, \"&modified\")"))'  2>/dev/null || echo "0")
      debug "check_unsaved_work: $result"
      echo "$result"
    }

    # Function to check for live processes (terminal mode)
    check_live_processes() {
      local result=$(${pkgs.neovim-remote}/bin/nvr --servername "$SERVER_NAME" \
        --remote-expr 'len(filter(range(1, bufnr("$")), "getbufvar(v:val, \"&terminal_job_pid\") != \"\""))' 2>/dev/null || echo "0")
      debug "check_live_processes: $result"
      echo "$result"
    }

    # Function to check if buffer is empty
    check_empty_buffer() {
      local result=$(${pkgs.neovim-remote}/bin/nvr --servername "$SERVER_NAME" \
        --remote-expr 'line("$") == 1 && getline(1) == "" && expand("%") == ""' 2>/dev/null || echo "0")
      debug "check_empty_buffer: $result"
      echo "$result"
    }

    # Function to launch new instance
    launch_new_instance() {
      debug "Launching new instance"
      rm -f "$SERVER_NAME"

      case "$MODE" in
        terminal)
          ${terminalBin} \
            --wayland_app_id "$APP_ID" \
            --fork \
            -- --listen "$SERVER_NAME" +terminal &
          ;;
        editor)
          if [ ''${#FILES[@]} -gt 0 ]; then
            ${terminalBin} \
              --wayland_app_id "$APP_ID" \
              --fork \
              -- --listen "$SERVER_NAME" "''${FILES[@]}" &
          else
            ${terminalBin} \
              --wayland_app_id "$APP_ID" \
              --fork \
              -- --listen "$SERVER_NAME" &
          fi
          ;;
        generic)
          # For generic apps, just launch terminal with command
          if [ ''${#FILES[@]} -gt 0 ]; then
            ${terminalBin} \
              --wayland_app_id "$APP_ID" \
              --fork \
              -- --listen "$SERVER_NAME" -c "terminal ''${FILES[0]}" -c "startinsert" &
          else
            ${terminalBin} \
              --wayland_app_id "$APP_ID" \
              --fork \
              -- --listen "$SERVER_NAME" +terminal &
          fi
          ;;
      esac
    }

    # Clean up stale socket if it exists but no process is listening
    if [ -S "$SERVER_NAME" ]; then
      if ! ${pkgs.neovim-remote}/bin/nvr --servername "$SERVER_NAME" --remote-send "" 2>/dev/null; then
        debug "Removing stale socket: $SERVER_NAME"
        rm -f "$SERVER_NAME"
      fi
    fi

    # Main logic
    switch_to_desktop

    # Check if workspace has any window
    HAS_WINDOW=$(check_workspace_has_window "$DESKTOP")

    if [ "$HAS_WINDOW" = "yes" ] && [ -n "$DESKTOP" ]; then
      debug "Workspace has a window, checking if we can connect to nvr"

      # Try to connect to nvr
      if wait_for_nvr; then
        debug "Connected to existing nvr instance"

        # Mode-specific behavior for existing windows
        case "$MODE" in
          editor)
            HAS_UNSAVED=$(check_unsaved_work)
            if [ "$HAS_UNSAVED" = "0" ]; then
              # No unsaved work
              IS_EMPTY=$(check_empty_buffer)
              debug "No unsaved work, empty buffer: $IS_EMPTY"

              if [ "$IS_EMPTY" = "1" ]; then
                # Empty buffer - can replace
                if [ ''${#FILES[@]} -gt 0 ]; then
                  debug "Opening files in empty buffer"
                  ${pkgs.neovim-remote}/bin/nvr --servername "$SERVER_NAME" \
                    --remote "''${FILES[@]}" 2>/dev/null
                fi
              else
                # Has content but no unsaved changes - replace buffer
                if [ ''${#FILES[@]} -gt 0 ]; then
                  debug "Replacing buffer with files"
                  ${pkgs.neovim-remote}/bin/nvr --servername "$SERVER_NAME" \
                    --remote "''${FILES[@]}" 2>/dev/null
                fi
              fi
            else
              # Has unsaved work - open in new tab
              debug "Has unsaved work, opening in new tab"
              if [ ''${#FILES[@]} -gt 0 ]; then
                ${pkgs.neovim-remote}/bin/nvr --servername "$SERVER_NAME" \
                  --remote-tab "''${FILES[@]}" 2>/dev/null
              else
                ${pkgs.neovim-remote}/bin/nvr --servername "$SERVER_NAME" \
                  --remote-send "<cmd>tabnew<CR>" 2>/dev/null
              fi
            fi
            ;;

          terminal)
            LIVE_PROCESSES=$(check_live_processes)
            if [ "$LIVE_PROCESSES" = "0" ]; then
              # No live processes - can reuse window
              debug "No live processes, reusing terminal"
              ${pkgs.neovim-remote}/bin/nvr --servername "$SERVER_NAME" \
                --remote-send "<cmd>enew | terminal<CR>" 2>/dev/null
            else
              # Has live processes - open in new tab
              debug "Has live processes, opening new terminal tab"
              ${pkgs.neovim-remote}/bin/nvr --servername "$SERVER_NAME" \
                --remote-send "<cmd>tabnew +terminal<CR>" 2>/dev/null
            fi
            ;;

          generic)
            # For generic apps, always create new tab
            debug "Generic app, creating new tab"
            if [ ''${#FILES[@]} -gt 0 ]; then
              ${pkgs.neovim-remote}/bin/nvr --servername "$SERVER_NAME" \
                --remote-send "<cmd>tabnew | terminal ''${FILES[0]}<CR>" 2>/dev/null
            else
              ${pkgs.neovim-remote}/bin/nvr --servername "$SERVER_NAME" \
                --remote-send "<cmd>tabnew +terminal<CR>" 2>/dev/null
            fi
            ;;
        esac
      else
        debug "Cannot connect to nvr, launching new instance"
        launch_new_instance
      fi
    else
      debug "No window on workspace or no desktop specified"
      launch_new_instance
    fi
  '';

  # Rest remains the same...
  createTerminalWithCommand = {
    appId,
    command,
    autoClose ? true,
  }:
    pkgs.writeShellScriptBin "terminal-${appId}" ''
      #!${pkgs.bash}/bin/bash
      export TERM=xterm-256color
      ${terminalBin} \
        --wayland_app_id "${appId}" \
        --fork \
        -- -c "terminal ${command}" \
        ${
        if autoClose
        then ''-c "autocmd TermClose * ++nested quit"''
        else ""
      }
    '';
in {
  # Terminal package info
  packageName = "${terminalPackage.pname}";
  iconName = "${terminalPackage.pname}";
  package = terminalPackage;
  bin = terminalBin;

  # Terminal launcher for managing instances
  inherit terminalLauncher;
  inherit createTerminalWithCommand;

  # Program configuration for the terminal
  programConfig = {
    enable = true;
    settings.fork = true;
  };

  # Support packages needed by the terminal
  supportPackages = with pkgs; [
    neovim-remote
  ];

  # Terminal app IDs
  appIds = {
    terminal = "${terminalPackage.pname}-terminal";
    editor = "${terminalPackage.pname}";
  };

  # Default launch commands
  defaultLaunchCmd = "${terminalBin} --fork";
  launchWithAppId = appId: "${terminalBin} --wayland_app_id ${appId} --fork";
  supportsCustomAppId = true;
  defaultAppId = "${terminalPackage.pname}";
  name = "${terminalPackage.pname}";
}
