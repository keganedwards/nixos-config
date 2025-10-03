{
  pkgs,
  appId,
  commandToRun,
  commandArgs ? "",
  config,
  appType ? "general", # Can be "editor", "terminal", or "gitui"
}:
pkgs.writeShellScriptBin "universal-multiplexer-launcher-${appId}" ''
  #!${pkgs.runtimeShell}
  set -e

  # --- Configuration ---
  APP_ID="${appId}"
  TERMINAL_BIN="${config.terminalConstants.bin}"
  MULTIPLEXER_CLI="${config.terminalConstants.bin} cli"
  COMMAND_TO_RUN="${commandToRun}"
  COMMAND_ARGS="${commandArgs}"
  APP_TYPE="${appType}"
  WM_MSG="${config.windowManagerConstants.msg}"

  # --- Dependencies ---
  JQ_BIN="${pkgs.jq}/bin/jq"
  BASENAME_BIN="${pkgs.coreutils}/bin/basename"
  DIRNAME_BIN="${pkgs.coreutils}/bin/dirname"
  REALPATH_BIN="${pkgs.coreutils}/bin/realpath"
  GIT_BIN="${pkgs.git}/bin/git"

  # Debug logging
  DEBUG_LOG="/tmp/multiplexer-launcher-debug.log"
  echo "[$(date)] Starting launcher for $APP_TYPE with args: $@" >> "$DEBUG_LOG"

  # --- Function Definitions ---

  get_window_id() {
    $WM_MSG -t get_tree 2>/dev/null | $JQ_BIN -r --arg appid "$APP_ID" \
      'first( .. | select(type == "object" and .app_id? == $appid) | .id ) // empty'
  }

  get_git_repo_root() {
    local check_dir="$1"
    if [ -z "$check_dir" ] || [ ! -d "$check_dir" ]; then
      check_dir="$PWD"
    fi
    (cd "$check_dir" 2>/dev/null && $GIT_BIN rev-parse --show-toplevel 2>/dev/null) || echo ""
  }

  get_multiplexer_panes() {
    # Get all panes and filter by the specific app_id window
    $MULTIPLEXER_CLI list --format json 2>/dev/null | \
      $JQ_BIN --arg appid "$APP_ID" '[.[] | select(.window_title | test($appid))]' || echo "[]"
  }

  find_existing_tab() {
    local target="$1"
    local panes=$(get_multiplexer_panes)

    echo "[$(date)] Looking for existing tab for: $target" >> "$DEBUG_LOG"
    echo "[$(date)] Current panes: $panes" >> "$DEBUG_LOG"

    case "$APP_TYPE" in
      "gitui")
        local repo_root=$(get_git_repo_root "$target")
        if [ -n "$repo_root" ]; then
          local repo_name=$($BASENAME_BIN "$repo_root")
          echo "$panes" | $JQ_BIN -r --arg name "$repo_name" '
            .[] | select(.title | contains($name)) | .pane_id' | head -1
        else
          local dir_name=$($BASENAME_BIN "$target")
          echo "$panes" | $JQ_BIN -r --arg name "gitui-$dir_name" '
            .[] | select(.title | contains($name)) | .pane_id' | head -1
        fi
        ;;
      "editor")
        local target_real=$($REALPATH_BIN "$target" 2>/dev/null) || target_real="$target"
        local target_basename=$($BASENAME_BIN "$target_real")

        echo "$panes" | $JQ_BIN -r --arg name "$target_basename" '
          .[] | select(.title | contains($name)) | .pane_id' | head -1
        ;;
      *)
        echo ""
        ;;
    esac
  }

  determine_working_directory() {
    local working_dir="$PWD"

    if [ "$APP_TYPE" = "gitui" ]; then
      # Try to get active pane's working directory from any wezterm window
      local active_pane=$($MULTIPLEXER_CLI list --format json 2>/dev/null | \
        $JQ_BIN -r '.[] | select(.is_active == true) | .cwd' | head -1)

      if [ -n "$active_pane" ] && [ -d "$active_pane" ]; then
        working_dir="$active_pane"
      else
        working_dir="$HOME"
      fi

      local repo_root=$(get_git_repo_root "$working_dir")
      if [ -n "$repo_root" ]; then
        working_dir="$repo_root"
      fi
    fi

    echo "$working_dir"
  }

  # --- Main Logic ---
  existing_window_id=$(get_window_id)
  WORKING_DIR=$(determine_working_directory)

  echo "[$(date)] Window ID: $existing_window_id, Working dir: $WORKING_DIR, App ID: $APP_ID" >> "$DEBUG_LOG"

  # For terminal apps, always create new window
  if [ "$APP_TYPE" = "terminal" ]; then
    echo "[$(date)] Creating new terminal window" >> "$DEBUG_LOG"
    "$TERMINAL_BIN" start --class "$APP_ID" --cwd="$WORKING_DIR" -- "$COMMAND_TO_RUN" >/dev/null 2>&1 &
    disown
    exit 0
  fi

  # For other app types, use tab logic
  if [ -n "$existing_window_id" ]; then
    echo "[$(date)] Focusing existing window: $existing_window_id" >> "$DEBUG_LOG"
    $WM_MSG "[con_id=$existing_window_id] focus" >/dev/null 2>&1

    # Check for existing tab with the target
    if [ "$APP_TYPE" = "gitui" ]; then
      existing_tab=$(find_existing_tab "$WORKING_DIR")
    elif [ "$#" -gt 0 ]; then
      existing_tab=$(find_existing_tab "$1")
    else
      existing_tab=""
    fi

    if [ -n "$existing_tab" ]; then
      echo "[$(date)] Found existing tab: $existing_tab" >> "$DEBUG_LOG"
      $MULTIPLEXER_CLI activate-pane --pane-id="$existing_tab" 2>/dev/null || true
    else
      echo "[$(date)] No existing tab found, creating new one" >> "$DEBUG_LOG"
      if [ $# -gt 0 ] && [ "$APP_TYPE" != "gitui" ]; then
        $MULTIPLEXER_CLI spawn --cwd="$WORKING_DIR" -- "$COMMAND_TO_RUN" "$@" 2>/dev/null
      else
        $MULTIPLEXER_CLI spawn --cwd="$WORKING_DIR" -- "$COMMAND_TO_RUN" 2>/dev/null
      fi
    fi
  else
    echo "[$(date)] Launching new terminal window with app_id: $APP_ID" >> "$DEBUG_LOG"

    if [ "$#" -gt 0 ] && [ "$APP_TYPE" != "gitui" ]; then
      "$TERMINAL_BIN" start --class "$APP_ID" --cwd="$WORKING_DIR" -- "$COMMAND_TO_RUN" "$@" >/dev/null 2>&1 &
    else
      "$TERMINAL_BIN" start --class "$APP_ID" --cwd="$WORKING_DIR" -- "$COMMAND_TO_RUN" >/dev/null 2>&1 &
    fi
    disown
  fi

  exit 0
''
