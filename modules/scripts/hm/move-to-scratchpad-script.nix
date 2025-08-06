# File: modules/home-manager/scripts/move-to-scratchpad-script.nix
{pkgs, ...}: {
  home.packages = [
    (pkgs.writeShellScriptBin "move-to-scratchpad" ''
      #!${pkgs.runtimeShell}
      set -eu

      # Expect the application identifier (app_id) as the first argument
      if [ -z "''${1:-}" ]; then
        echo "Usage: move-to-scratchpad <app_id>" >&2
        exit 1
      fi
      appIdentifier="$1"

      # Loop for up to 20 seconds waiting for the application window
      for i in $(seq 1 20); do
        # Check if a window with the exact app_id exists
        if ${pkgs.sway}/bin/swaymsg -t get_tree | ${pkgs.jq}/bin/jq -e --arg APPID "$appIdentifier" '.. | select(.app_id? == $APPID)' > /dev/null; then
          # If found, move it to the scratchpad and exit successfully
          ${pkgs.sway}/bin/swaymsg "[app_id=\"$appIdentifier\"] move container to scratchpad"
          exit 0
        fi
        # If not found, wait a second and try again
        sleep 1
      done

      # If the loop finishes, print a warning and exit with failure
      echo "Warning: Timed out after 20s waiting for '$appIdentifier' to move to scratchpad." >&2
      exit 1
    '')
  ];
}
