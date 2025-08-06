# File: modules/home-manager/apps/definitions/e-text-editor/_smart-editor-launcher-script.nix
{
  pkgs,
  defaultEditorLaunchCmd,
  ...
}:
pkgs.writeShellScriptBin "smart-editor-launcher" ''
  #!${pkgs.runtimeShell}
  set -e

  # Configuration
  DEFAULT_EDITOR_LAUNCH_CMD="${defaultEditorLaunchCmd}"
  STAT_BIN="${pkgs.coreutils}/bin/stat"

  # Check if any arguments are files owned by root
  needs_sudo=false
  for arg in "$@"; do
    if [ -f "$arg" ]; then
      owner_uid=$($STAT_BIN -c '%u' "$arg" 2>/dev/null || echo "")
      if [ "$owner_uid" = "0" ]; then
        needs_sudo=true
        break
      fi
    fi
  done

  # Launch the appropriate editor
  if [ "$needs_sudo" = "true" ]; then
    # Pass the special flag to indicate sudoedit should be used
    exec "$DEFAULT_EDITOR_LAUNCH_CMD" --use-sudoedit "$@"
  else
    # Normal editor launch
    exec "$DEFAULT_EDITOR_LAUNCH_CMD" "$@"
  fi
''
