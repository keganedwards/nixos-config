{
  config,
  pkgs,
  username,
  ...
}: let
  wmConstants = config.windowManagerConstants;
in {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "wm-reload-env" ''
      set -e
      SOCK_PATH="${wmConstants.session.socketPath}"
      export SWAYSOCK="$SOCK_PATH"
      echo "SWAYSOCK set to $SWAYSOCK"

      if [ -n "$TMUX" ]; then
        ${pkgs.tmux}/bin/tmux set-environment -g SWAYSOCK "$SWAYSOCK"
        echo "Also updated tmux environment SWAYSOCK"
      fi

      echo "Reloading window manager configuration..."
      ${wmConstants.reload}

      echo "Window manager environment reload complete."
    '')
  ];

  home-manager.users.${username}.wayland.windowManager.sway.config.keybindings."mod4+Shift+r" = "exec wm-reload-env";
}
