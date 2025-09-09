# /.dotfiles/nixos/home-manager-modules/programs/multiplexer.nix
{
  pkgs,
  username,
  ...
}: let
  protectedUsername = "protect-${username}";
in {
  # Protected user owns the configuration
  home-manager.users.${protectedUsername} = {config, ...}: {
    programs.tmux = let
      altFKeyWindowBindings = builtins.concatStringsSep "\n" (
        map (
          i: let
            windowNumStr = builtins.toString i;
            fKeyNumStr = builtins.toString i;
          in ''
            # Window ${windowNumStr} (Alt+F${fKeyNumStr})
            bind -n M-F${fKeyNumStr} run-shell "if ! tmux list-windows -F '#I' | grep -q '^${windowNumStr}$'; then tmux new-window -t ${windowNumStr} -n 'W${windowNumStr}' -d; fi; tmux select-window -t ${windowNumStr}"
          ''
        ) (pkgs.lib.range config.programs.tmux.baseIndex (config.programs.tmux.baseIndex + 6))
        ++ [
          ''
            # Window 0 (Alt+F10)
            bind -n M-F10 run-shell "if ! tmux list-windows -F '#I' | grep -q '^0$'; then tmux new-window -t 0 -n 'W0' -d; fi; tmux select-window -t 0"
          ''
        ]
      );
    in {
      enable = true;
      baseIndex = 3;
      keyMode = "vi";
      newSession = false;
      terminal = "tmux-256color";

      extraConfig = ''
        # Ensure proper color support
        set -g default-terminal "tmux-256color"
        set -ga terminal-overrides ",*256col*:Tc"
        set -ga terminal-overrides ",foot:RGB"

        # Set pane base index to match window base index for consistency
        setw -g pane-base-index ${builtins.toString config.programs.tmux.baseIndex};

        # --- IMPORTANT for Sway IPC (and other graphical session info) ---
        set-option -g update-environment "DISPLAY WAYLAND_DISPLAY SWAYSOCK SSH_AUTH_SOCK XAUTHORITY XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_CURRENT_DESKTOP XDG_SESSION_TYPE LANG LC_ALL LANGUAGE TERM COLORTERM NIXOS_OZONE_WL GTK_THEME QT_STYLE_OVERRIDE"

        # --- Status Bar Customization ---
        set-option -g status-right ""

        # --- Custom Key Bindings ---
        ${altFKeyWindowBindings}

        # Close current window/tab instantly with Alt+Delete (no confirmation)
        bind-key -n M-Delete kill-window

        # --- Scrollback configuration for foot terminal ---
        bind-key -n S-PPage copy-mode -u
        bind-key -n S-NPage send-keys -X page-down
      '';
    };
  };

  # Main user just gets the package
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      tmux
    ];
  };
}
