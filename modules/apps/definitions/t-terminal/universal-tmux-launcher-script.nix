{
  pkgs,
  appId,
  sessionName,
  terminalBin,
  commandToRun,
  commandArgs ? "",
  appType ? "general", # Can be "editor", "terminal", or "gitui"
}:
pkgs.writeShellScriptBin "universal-tmux-launcher-${appId}" ''
  #!${pkgs.runtimeShell}
  set -e

  # --- Configuration ---
  APP_ID="${appId}"
  SESSION_NAME="${sessionName}"
  TERMINAL_BIN="${terminalBin}"
  COMMAND_TO_RUN="${commandToRun}"
  COMMAND_ARGS="${commandArgs}"
  APP_TYPE="${appType}"
  MULTIPLEXER_BASE_INDEX=3

  # --- Dependencies ---
  SWAYMSG_BIN="${pkgs.sway}/bin/swaymsg"
  JQ_BIN="${pkgs.jq}/bin/jq"
  MULTIPLEXER_BIN="${pkgs.tmux}/bin/tmux"
  BASENAME_BIN="${pkgs.coreutils}/bin/basename"
  DIRNAME_BIN="${pkgs.coreutils}/bin/dirname"
  REALPATH_BIN="${pkgs.coreutils}/bin/realpath"
  GIT_BIN="${pkgs.git}/bin/git"

  # Debug logging
  DEBUG_LOG="/tmp/tmux-launcher-debug.log"
  echo "[$(date)] Starting launcher for $APP_TYPE with PWD=$PWD" >> "$DEBUG_LOG"
  echo "[$(date)] Session name: $SESSION_NAME" >> "$DEBUG_LOG"
  echo "[$(date)] Args: $@" >> "$DEBUG_LOG"

  # --- Handle Special Flags ---
  USE_SUDOEDIT=false
  if [ "$1" = "--use-sudoedit" ]; then
    USE_SUDOEDIT=true
    shift # Remove the flag from arguments
    COMMAND_TO_RUN="sudoedit"
  fi

  # --- Function Definitions ---

  # Debug function to capture window state
  debug_window_state() {
    local window_id="$1"
    local context="$2"
    local debug_file="/tmp/tmux-window-debug-$window_id-$(date +%s).txt"

    echo "[$(date)] === Window State Debug: $context (Window $window_id) ===" >> "$debug_file"

    # Capture tmux show-environment for the session
    echo "=== Session Environment ===" >> "$debug_file"
    $MULTIPLEXER_BIN show-environment -t "$SESSION_NAME" >> "$debug_file" 2>&1 || true

    # Capture window options
    echo -e "\n=== Window Options ===" >> "$debug_file"
    $MULTIPLEXER_BIN show-window-options -t "$SESSION_NAME:$window_id" >> "$debug_file" 2>&1 || true

    # Capture pane info
    echo -e "\n=== Pane Info ===" >> "$debug_file"
    $MULTIPLEXER_BIN list-panes -t "$SESSION_NAME:$window_id" -F 'Pane #{pane_index}: cmd=#{pane_current_command} path=#{pane_current_path}' >> "$debug_file" 2>&1 || true

    # Try to capture what nvim sees
    if [ "$APP_TYPE" = "editor" ] && [ "$context" != "dummy" ]; then
      echo -e "\n=== Attempting to capture nvim environment ===" >> "$debug_file"
      # Send command to nvim to output environment to a file
      $MULTIPLEXER_BIN send-keys -t "$SESSION_NAME:$window_id" Escape ":!env | grep -i 'term\\|color' > /tmp/nvim-env-$window_id.txt" Enter 2>/dev/null || true
      sleep 0.5
      $MULTIPLEXER_BIN send-keys -t "$SESSION_NAME:$window_id" Enter 2>/dev/null || true
    fi

    echo "[$(date)] Debug info saved to: $debug_file" >> "$DEBUG_LOG"
  }

  get_sway_window_id() {
    local sway_output
    sway_output=$($SWAYMSG_BIN -t get_tree 2>/dev/null)
    if [ -z "$sway_output" ]; then
      echo "" # Return empty string
      return
    fi
    echo "$sway_output" | $JQ_BIN -r --arg appid "$APP_ID" \
      'first( .. | select(type == "object" and .app_id? == $appid) | .id ) // empty'
  }

  get_focused_window_info() {
    local sway_output
    sway_output=$($SWAYMSG_BIN -t get_tree 2>/dev/null)
    if [ -z "$sway_output" ]; then
      echo ""
      return
    fi

    # Get the focused window's app_id
    local focused_app_id
    focused_app_id=$(echo "$sway_output" | $JQ_BIN -r '.. | select(.focused? == true) | .app_id // empty')

    echo "[$(date)] Focused window app_id: $focused_app_id" >> "$DEBUG_LOG"
    echo "$focused_app_id"
  }

  get_current_tmux_pane_directory() {
    # Hardcode to use the "terminal" session since that's where directory navigation happens
    local terminal_session="terminal"
    local current_dir=""

    echo "[$(date)] Checking terminal session: $terminal_session" >> "$DEBUG_LOG"

    # Check if the terminal session exists
    if $MULTIPLEXER_BIN has-session -t "$terminal_session" 2>/dev/null; then
      # Get the current directory from the terminal session
      current_dir=$($MULTIPLEXER_BIN display-message -p -t "$terminal_session" -F "#{pane_current_path}" 2>/dev/null || true)
      echo "[$(date)] Current dir from terminal session: $current_dir" >> "$DEBUG_LOG"
    else
      echo "[$(date)] Terminal session does not exist" >> "$DEBUG_LOG"
    fi

    # If terminal session didn't work, fall back to any session
    if [ -z "$current_dir" ] || [ ! -d "$current_dir" ]; then
      echo "[$(date)] Falling back to any session" >> "$DEBUG_LOG"
      current_dir=$($MULTIPLEXER_BIN list-panes -a -F "#{pane_current_path}" 2>/dev/null | head -1)
      echo "[$(date)] Fallback dir: $current_dir" >> "$DEBUG_LOG"
    fi

    # Validate the directory
    if [ -n "$current_dir" ] && [ -d "$current_dir" ]; then
      echo "$current_dir"
    else
      echo ""
    fi
  }

  get_git_repo_root() {
    # Get the git repository root directory
    local check_dir="$1"
    if [ -z "$check_dir" ] || [ ! -d "$check_dir" ]; then
      check_dir="$PWD"
    fi

    # Change to the directory and find the git root
    local repo_root
    repo_root=$(cd "$check_dir" 2>/dev/null && $GIT_BIN rev-parse --show-toplevel 2>/dev/null) || echo ""

    echo "$repo_root"
  }

  get_window_name_for_gitui() {
    local dir="$1"
    local repo_root
    repo_root=$(get_git_repo_root "$dir")

    if [ -n "$repo_root" ]; then
      # In a git repo - use repo name
      echo "$($BASENAME_BIN "$repo_root")"
    else
      # Not in a git repo - for gitui, this is unusual
      # Use a descriptive name instead of just the directory basename
      if [ "$dir" = "$HOME" ]; then
        echo "gitui-home"
      else
        local dirname="$($BASENAME_BIN "$dir")"
        # Prefix with gitui- to make it clear this is a non-repo gitui window
        echo "gitui-$dirname"
      fi
    fi
  }

  find_tmux_window_for_gitui() {
    local target_dir="$1"
    local window_list

    # List all windows in the session with their pane's current path
    window_list=$($MULTIPLEXER_BIN list-windows -t "$SESSION_NAME" -F "#{window_index}:#{window_name}:#{pane_current_path}" 2>/dev/null) || return 1

    echo "[$(date)] Looking for gitui window matching dir: $target_dir" >> "$DEBUG_LOG"
    echo "[$(date)] Window list: $window_list" >> "$DEBUG_LOG"

    # For gitui, we want to find a window that:
    # 1. Has the same git repo root as our target
    # 2. Or if not in a repo, has the same directory

    local target_repo_root
    target_repo_root=$(get_git_repo_root "$target_dir")

    echo "[$(date)] Target repo root: $target_repo_root" >> "$DEBUG_LOG"

    if [ -n "$target_repo_root" ]; then
      # We're looking for a window in the same git repo
      while IFS=: read -r index name pane_path; do
        if [ -n "$pane_path" ]; then
          local window_repo_root
          window_repo_root=$(get_git_repo_root "$pane_path")
          echo "[$(date)] Window $index ($name) at $pane_path has repo root: $window_repo_root" >> "$DEBUG_LOG"
          if [ "$window_repo_root" = "$target_repo_root" ]; then
            echo "[$(date)] Found matching repo window: $index" >> "$DEBUG_LOG"
            echo "$index"
            return 0
          fi
        fi
      done <<< "$window_list"
    else
      # Not in a git repo, look for exact directory match
      local expected_name=$(get_window_name_for_gitui "$target_dir")
      echo "[$(date)] Looking for non-repo window with name: $expected_name" >> "$DEBUG_LOG"
      while IFS=: read -r index name pane_path; do
        echo "[$(date)] Checking window $index: name='$name', pane_path='$pane_path'" >> "$DEBUG_LOG"
        if [ "$name" = "$expected_name" ] && [ "$pane_path" = "$target_dir" ]; then
          echo "[$(date)] Found matching non-repo window: $index" >> "$DEBUG_LOG"
          echo "$index"
          return 0
        fi
      done <<< "$window_list"
    fi

    echo "[$(date)] No matching window found" >> "$DEBUG_LOG"
    return 1
  }

  find_tmux_window_for_editor() {
    local target_file="$1"
    local target_file_real
    target_file_real=$($REALPATH_BIN "$target_file" 2>/dev/null) || target_file_real="$target_file"

    echo "[$(date)] Looking for editor window for file: $target_file_real" >> "$DEBUG_LOG"

    # Store window information with commands that contain our target file
    local window_matches=""
    local window_list
    window_list=$($MULTIPLEXER_BIN list-windows -t "$SESSION_NAME" -F "#{window_index}:#{window_name}:#{pane_current_command}:#{pane_current_path}" 2>/dev/null) || return 1

    echo "[$(date)] Editor window list: $window_list" >> "$DEBUG_LOG"

    # For each window, check if it's editing our target file
    while IFS=: read -r index name command pane_path; do
      if [ "$command" = "nvim" ] || [ "$command" = "$COMMAND_TO_RUN" ]; then
        # Get list of all panes in this window
        local pane_list
        pane_list=$($MULTIPLEXER_BIN list-panes -t "$SESSION_NAME:$index" -F "#{pane_index}:#{pane_current_command}" 2>/dev/null)

        # Check the first pane (usually the main editor pane)
        local first_pane_cmd
        first_pane_cmd=$(echo "$pane_list" | head -1 | cut -d: -f2)

        if [ "$first_pane_cmd" = "nvim" ] || [ "$first_pane_cmd" = "$COMMAND_TO_RUN" ]; then
          # Try to see if this window has our file by checking the window name
          # This is a simplified check - if the basename matches and the path seems right
          local file_basename="$($BASENAME_BIN "$target_file_real")"
          local window_basename="$name"

          if [ "$window_basename" = "$file_basename" ]; then
            # Check if the pane path is compatible with our file path
            local file_dir="$($DIRNAME_BIN "$target_file_real")"
            if [ "$pane_path" = "$file_dir" ]; then
              echo "[$(date)] Found matching editor window: $index" >> "$DEBUG_LOG"
              echo "$index"
              return 0
            fi
          fi
        fi
      fi
    done <<< "$window_list"

    echo "[$(date)] No matching editor window found" >> "$DEBUG_LOG"
    return 1
  }

  find_tmux_window_for_target() {
    local target="$1"

    case "$APP_TYPE" in
      "gitui")
        find_tmux_window_for_gitui "$target"
        ;;
      "editor")
        find_tmux_window_for_editor "$target"
        ;;
      "terminal"|*)
        # For terminal, check if any window is in the target directory
        local dir_basename="$($BASENAME_BIN "$target")"
        local window_list=$($MULTIPLEXER_BIN list-windows -t "$SESSION_NAME" -F "#{window_index}:#{window_name}" 2>/dev/null) || return 1
        echo "$window_list" | grep -F ":$dir_basename$" | cut -d':' -f1 | head -1
        ;;
    esac
  }

  determine_working_directory() {
    local working_dir="$PWD"

    if [ "$APP_TYPE" = "gitui" ]; then
      # Check if the focused window is a terminal
      local focused_app_id
      focused_app_id=$(get_focused_window_info)

      echo "[$(date)] Focused app_id: $focused_app_id" >> "$DEBUG_LOG"

      # Check if it's a terminal (foot, alacritty, etc.)
      if [[ "$focused_app_id" == *"terminal"* ]] || [[ "$focused_app_id" == "foot" ]] || [[ "$focused_app_id" == "alacritty" ]] || [[ "$focused_app_id" == "kitty" ]]; then
        echo "[$(date)] Focused window is a terminal, trying to get tmux pane directory" >> "$DEBUG_LOG"

        # Try to get the current tmux pane's directory from the terminal session
        local tmux_dir
        tmux_dir=$(get_current_tmux_pane_directory)

        if [ -n "$tmux_dir" ] && [ -d "$tmux_dir" ]; then
          working_dir="$tmux_dir"
          echo "[$(date)] Got working directory from tmux: $working_dir" >> "$DEBUG_LOG"
        else
          echo "[$(date)] Could not get tmux directory, using HOME: $HOME" >> "$DEBUG_LOG"
          working_dir="$HOME"
        fi
      else
        echo "[$(date)] Focused window is not a terminal, using HOME: $HOME" >> "$DEBUG_LOG"
        working_dir="$HOME"
      fi

      # If we found a directory, check if it's in a git repo
      local repo_root
      repo_root=$(get_git_repo_root "$working_dir")
      if [ -n "$repo_root" ]; then
        working_dir="$repo_root"
        echo "[$(date)] Using git repo root: $working_dir" >> "$DEBUG_LOG"
      fi
    fi

    echo "$working_dir"
  }

  # Function to persistently set gitui window name
  persist_gitui_window_name() {
    local window_target="$1"
    local window_name="$2"

    echo "[$(date)] Persisting gitui window name: $window_target -> $window_name" >> "$DEBUG_LOG"

    # Create a background process that will keep the window name set
    (
      # Initial settings
      $MULTIPLEXER_BIN set-window-option -t "$window_target" automatic-rename off 2>/dev/null
      $MULTIPLEXER_BIN set-window-option -t "$window_target" allow-rename off 2>/dev/null
      $MULTIPLEXER_BIN rename-window -t "$window_target" "$window_name" 2>/dev/null

      # Keep checking and fixing the name for a few seconds
      for i in {1..10}; do
        sleep 0.5
        # Check current name
        current_name=$($MULTIPLEXER_BIN display-message -p -t "$window_target" -F '#{window_name}' 2>/dev/null || echo "")
        if [ "$current_name" != "$window_name" ]; then
          echo "[$(date)] Fixing window name from '$current_name' back to '$window_name'" >> "$DEBUG_LOG"
          $MULTIPLEXER_BIN rename-window -t "$window_target" "$window_name" 2>/dev/null
        fi
      done
    ) &
    disown
  }

  # --- Main Logic ---
  existing_sway_window_con_id=$(get_sway_window_id)
  TERMINAL_ATTACH_TARGET="$SESSION_NAME:$MULTIPLEXER_BASE_INDEX"

  # Determine the working directory intelligently
  WORKING_DIR=$(determine_working_directory)
  echo "[$(date)] Final working directory: $WORKING_DIR" >> "$DEBUG_LOG"

  if [ -n "$existing_sway_window_con_id" ]; then
    # BRANCH: Existing Sway window (terminal with app_id) FOUND.
    echo "[$(date)] Found existing Sway window: $existing_sway_window_con_id" >> "$DEBUG_LOG"

    # Focus it first
    $SWAYMSG_BIN "[con_id=$existing_sway_window_con_id] focus" >/dev/null 2>&1

    # Ensure the multiplexer session exists
    if ! $MULTIPLEXER_BIN has-session -t "$SESSION_NAME" 2>/dev/null; then
      # The terminal exists but no multiplexer session - create a session
      initial_window_name="$($BASENAME_BIN "$COMMAND_TO_RUN")"
      if [ "$APP_TYPE" = "gitui" ]; then
        initial_window_name=$(get_window_name_for_gitui "$WORKING_DIR")
      elif [ "$#" -gt 0 ]; then
        initial_window_name="$($BASENAME_BIN "$1")"
      fi

      echo "[$(date)] Creating new session with window name: $initial_window_name in dir: $WORKING_DIR" >> "$DEBUG_LOG"

      # Create session with proper working directory AND pass arguments to initial window
      if [ "$#" -gt 0 ] && [ "$APP_TYPE" != "gitui" ]; then
        (cd "$WORKING_DIR" && "$MULTIPLEXER_BIN" new-session -d -s "$SESSION_NAME" -n "$initial_window_name" "$COMMAND_TO_RUN" "$@") >/dev/null 2>&1
      else
        (cd "$WORKING_DIR" && "$MULTIPLEXER_BIN" new-session -d -s "$SESSION_NAME" -n "$initial_window_name" "$COMMAND_TO_RUN") >/dev/null 2>&1
      fi

      # Debug the initial window state for editor
      if [ "$APP_TYPE" = "editor" ]; then
        sleep 0.5
        debug_window_state "$MULTIPLEXER_BASE_INDEX" "initial-session-window"
      fi

      # Handle gitui window naming
      if [ "$APP_TYPE" = "gitui" ]; then
        persist_gitui_window_name "$SESSION_NAME:$MULTIPLEXER_BASE_INDEX" "$initial_window_name"
      fi

      # Send keys to attach to the session in the existing terminal
      $MULTIPLEXER_BIN send-keys -t "$SESSION_NAME:$MULTIPLEXER_BASE_INDEX" C-c Enter
      $MULTIPLEXER_BIN send-keys -t "$SESSION_NAME:$MULTIPLEXER_BASE_INDEX" "$MULTIPLEXER_BIN attach-session -t $SESSION_NAME:$MULTIPLEXER_BASE_INDEX" Enter
    else
      # Session exists, check if a window for the target already exists
      existing_window_index=""

      if [ "$APP_TYPE" = "gitui" ]; then
        # For gitui, check based on the working directory
        existing_window_index=$(find_tmux_window_for_target "$WORKING_DIR" || echo "")
        echo "[$(date)] Existing gitui window index: $existing_window_index" >> "$DEBUG_LOG"
      elif [ "$#" -gt 0 ]; then
        # For other types, check if a window for this target already exists
        existing_window_index=$(find_tmux_window_for_target "$1" || echo "")
        echo "[$(date)] Existing window index for $1: $existing_window_index" >> "$DEBUG_LOG"
      fi

      if [ -n "$existing_window_index" ]; then
        # Window exists, switch to it
        echo "[$(date)] Switching to existing window: $existing_window_index" >> "$DEBUG_LOG"
        $MULTIPLEXER_BIN select-window -t "$SESSION_NAME:$existing_window_index" 2>/dev/null || true
      else
        # Create new window
        echo "[$(date)] Creating new window" >> "$DEBUG_LOG"

        window_name=""
        if [ "$APP_TYPE" = "gitui" ]; then
          window_name=$(get_window_name_for_gitui "$WORKING_DIR")
        elif [ "$#" -gt 0 ]; then
          window_name="$($BASENAME_BIN "$1")"
        else
          window_name="$($BASENAME_BIN "$COMMAND_TO_RUN")"
        fi

        echo "[$(date)] Creating new window: $window_name in dir: $WORKING_DIR" >> "$DEBUG_LOG"

        # Create new window with proper working directory
        if [ "$APP_TYPE" = "gitui" ]; then
          # For gitui, wrap the command to prevent it from setting terminal title
          new_window_id=$(cd "$WORKING_DIR" && "$MULTIPLEXER_BIN" new-window -P -F "#{window_index}" -n "$window_name" -t "$SESSION_NAME:" \
            "printf '\\033]2;%s\\007' '$window_name'; $COMMAND_TO_RUN" 2>&1)
          echo "[$(date)] New gitui window result: $new_window_id" >> "$DEBUG_LOG"

          # Handle gitui window naming
          if [ -n "$new_window_id" ]; then
            persist_gitui_window_name "$SESSION_NAME:$new_window_id" "$window_name"
            # Switch to the new window
            $MULTIPLEXER_BIN select-window -t "$SESSION_NAME:$new_window_id" 2>/dev/null || true
          fi
        else
          new_window_id=$("$MULTIPLEXER_BIN" new-window -P -F "#{window_index}" -n "$window_name" -t "$SESSION_NAME:" -c "$WORKING_DIR" "$COMMAND_TO_RUN" "$@" 2>/dev/null)
          echo "[$(date)] New window result: $new_window_id" >> "$DEBUG_LOG"

          # Debug the new window state for editor
          if [ "$APP_TYPE" = "editor" ] && [ -n "$new_window_id" ]; then
            sleep 0.5
            debug_window_state "$new_window_id" "subsequent-window"
          fi

          # Switch to the new window
          if [ -n "$new_window_id" ]; then
            $MULTIPLEXER_BIN select-window -t "$SESSION_NAME:$new_window_id" 2>/dev/null || true
          fi
        fi
      fi
    fi

  else
    # BRANCH: No existing Sway window found.
    echo "[$(date)] No existing Sway window found, creating new terminal" >> "$DEBUG_LOG"

    $MULTIPLEXER_BIN start-server 2>/dev/null || true

    if ! $MULTIPLEXER_BIN has-session -t "$SESSION_NAME" 2>/dev/null; then
      # Create new session
      initial_window_name="$($BASENAME_BIN "$COMMAND_TO_RUN")"
      if [ "$APP_TYPE" = "gitui" ]; then
        initial_window_name=$(get_window_name_for_gitui "$WORKING_DIR")
      elif [ "$#" -gt 0 ]; then
        initial_window_name="$($BASENAME_BIN "$1")"
      fi

      echo "[$(date)] Creating new session with window: $initial_window_name in dir: $WORKING_DIR" >> "$DEBUG_LOG"

      # Create session with proper working directory AND pass arguments to initial window
      if [ "$#" -gt 0 ] && [ "$APP_TYPE" != "gitui" ]; then
        (cd "$WORKING_DIR" && "$MULTIPLEXER_BIN" new-session -d -s "$SESSION_NAME" -n "$initial_window_name" "$COMMAND_TO_RUN" "$@") >/dev/null 2>&1
      elif [ "$APP_TYPE" = "gitui" ]; then
        # For gitui, wrap the command to prevent it from setting terminal title
        (cd "$WORKING_DIR" && "$MULTIPLEXER_BIN" new-session -d -s "$SESSION_NAME" -n "$initial_window_name" \
          "printf '\\033]2;%s\\007' '$initial_window_name'; $COMMAND_TO_RUN") >/dev/null 2>&1
      else
        (cd "$WORKING_DIR" && "$MULTIPLEXER_BIN" new-session -d -s "$SESSION_NAME" -n "$initial_window_name" "$COMMAND_TO_RUN") >/dev/null 2>&1
      fi

      # Debug the initial window state for editor
      if [ "$APP_TYPE" = "editor" ]; then
        sleep 0.5
        debug_window_state "$MULTIPLEXER_BASE_INDEX" "initial-session-window-no-terminal"
      fi

      # Handle gitui window naming
      if [ "$APP_TYPE" = "gitui" ]; then
        persist_gitui_window_name "$SESSION_NAME:$MULTIPLEXER_BASE_INDEX" "$initial_window_name"
      fi

    else
      # Session exists, handle appropriately
      if [ "$APP_TYPE" = "gitui" ]; then
        # Check if a window for this working directory already exists
        existing_window_index=$(find_tmux_window_for_target "$WORKING_DIR" || echo "")
        echo "[$(date)] Existing gitui window check result: $existing_window_index" >> "$DEBUG_LOG"

        if [ -n "$existing_window_index" ]; then
          # Window exists, set it as the attach target
          TERMINAL_ATTACH_TARGET="$SESSION_NAME:$existing_window_index"
          echo "[$(date)] Using existing gitui window: $existing_window_index" >> "$DEBUG_LOG"
        else
          # Create new window for gitui
          window_name_file=$(get_window_name_for_gitui "$WORKING_DIR")

          echo "[$(date)] Creating detached gitui window: $window_name_file in dir: $WORKING_DIR" >> "$DEBUG_LOG"

          # For gitui, wrap the command to prevent it from setting terminal title
          window_spec=$(cd "$WORKING_DIR" && "$MULTIPLEXER_BIN" new-window -d -P -F "#{session_name}:#{window_index}" -n "$window_name_file" -t "$SESSION_NAME:" \
            "printf '\\033]2;%s\\007' '$window_name_file'; $COMMAND_TO_RUN" 2>&1)
          echo "[$(date)] Gitui window spec result: $window_spec" >> "$DEBUG_LOG"

          if [ -n "$window_spec" ]; then
            # Extract window index and handle naming
            window_index=$(echo "$window_spec" | cut -d':' -f2)
            persist_gitui_window_name "$SESSION_NAME:$window_index" "$window_name_file"
            TERMINAL_ATTACH_TARGET="$window_spec"
          fi
        fi
      elif [ "$#" -gt 0 ]; then
        # Handle non-gitui apps with arguments
        existing_window_index=$(find_tmux_window_for_target "$1" || echo "")

        if [ -n "$existing_window_index" ]; then
          TERMINAL_ATTACH_TARGET="$SESSION_NAME:$existing_window_index"
        else
          last_created_window_target=""
          for file_arg in "$@"; do
            window_name_file="$($BASENAME_BIN "$file_arg")"
            window_spec=$("$MULTIPLEXER_BIN" new-window -d -P -F "#{session_name}:#{window_index}" -n "$window_name_file" -t "$SESSION_NAME:" -c "$WORKING_DIR" "$COMMAND_TO_RUN" "$file_arg" 2>/dev/null)
            if [ -n "$window_spec" ]; then
              last_created_window_target="$window_spec"
            fi
          done

          if [ -n "$last_created_window_target" ]; then
            TERMINAL_ATTACH_TARGET="$last_created_window_target"
          fi
        fi
      else
        # No arguments, just create a new window if needed
        window_name="$($BASENAME_BIN "$COMMAND_TO_RUN")"
        new_window_spec=$("$MULTIPLEXER_BIN" new-window -d -P -F "#{session_name}:#{window_index}" -n "$window_name" -t "$SESSION_NAME:" -c "$WORKING_DIR" "$COMMAND_TO_RUN" 2>/dev/null)
        if [ -n "$new_window_spec" ]; then
          TERMINAL_ATTACH_TARGET="$new_window_spec"
        fi
      fi
    fi

    echo "[$(date)] Launching terminal with attach target: $TERMINAL_ATTACH_TARGET" >> "$DEBUG_LOG"

    # --- Launch Terminal ---
    "$TERMINAL_BIN" --app-id="$APP_ID" \
        "$MULTIPLEXER_BIN" attach-session -t "$TERMINAL_ATTACH_TARGET" \
        >/dev/null 2>&1 &
    disown
  fi

  exit 0
''
