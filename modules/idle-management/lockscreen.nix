{pkgs, ...}: let
  timeoutConfig = import ../../shared/timeout-delays.nix;
in
  pkgs.writeShellScriptBin "lockscreen" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    WALLPAPER="$HOME/.local/share/wallpapers/Bing/lockscreen.jpg"
    USER=$(${pkgs.coreutils}/bin/whoami)

    # Check if user is currently locked out via faillock
    if ${pkgs.linux-pam}/bin/faillock --dir /var/lib/faillock --user "$USER" 2>/dev/null | ${pkgs.ripgrep}/bin/rg -q "^When:"; then
      FAILURES=$(${pkgs.linux-pam}/bin/faillock --dir /var/lib/faillock --user "$USER" 2>/dev/null | \
        ${pkgs.ripgrep}/bin/rg -c "^When:")

      if [[ "$FAILURES" -ge ${toString timeoutConfig.firstTimeoutAttempts} ]]; then
        ${pkgs.libnotify}/bin/notify-send -u critical \
          "Account Locked" \
          "Authentication blocked after $FAILURES failed attempts" \
          -t 10000 || true

        echo "User locked out with $FAILURES failures - showing black screen"
        # Force black screen when locked out - no wallpaper option
        exec ${pkgs.swaylock}/bin/swaylock --color 000000 --show-failed-attempts --ignore-empty-password
      fi
    fi

    # Normal lockscreen with wallpaper
    if [[ -f "$WALLPAPER" ]]; then
      exec ${pkgs.swaylock}/bin/swaylock \
        --image "$WALLPAPER" \
        --font "Fira Code" \
        --show-failed-attempts
    else
      exec ${pkgs.swaylock}/bin/swaylock \
        --color 000000 \
        --show-failed-attempts
    fi
  ''
