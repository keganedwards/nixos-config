{
  fullName,
  email,
  ...
}: {
  programs.fish.shellInit = ''
    # Unset potentially dangerous environment variables
    set -e LD_PRELOAD
    set -e LD_LIBRARY_PATH
    set -e PYTHONPATH

    # Set protected environment variables (with readonly-like enforcement)
    set -gx GIT_AUTHOR_NAME "${fullName}"
    set -gx GIT_AUTHOR_EMAIL "${email}"
    set -gx GIT_COMMITTER_NAME "${fullName}"
    set -gx GIT_COMMITTER_EMAIL "${email}"

    # Mark these as universal to prevent tampering
    set -Ux GIT_AUTHOR_NAME "${fullName}"
    set -Ux GIT_AUTHOR_EMAIL "${email}"
    set -Ux GIT_COMMITTER_NAME "${fullName}"
    set -Ux GIT_COMMITTER_EMAIL "${email}"
  '';

  # Override the set command to prevent PATH tampering
  xdg.configFile = {
    "fish/functions/set.fish".text = ''
      function set --description 'Override set to protect PATH'
        # Check if trying to modify PATH
        if test (count $argv) -ge 2; and test "$argv[1]" = "-x" -o "$argv[1]" = "--export"; and test "$argv[2]" = "PATH"
          # Intercept PATH modification
          echo "PATH modification blocked for security" >&2
          return 1
        else if test (count $argv) -ge 1; and test "$argv[1]" = "PATH"
          # Also block non-export PATH modification
          echo "PATH modification blocked for security" >&2
          return 1
        else if string match -q "*PATH*" -- $argv
          # Block any PATH manipulation
          echo "PATH modification blocked for security" >&2
          return 1
        else
          # Allow other set operations
          builtin set $argv
        end
      end
    '';

    # Set PATH immutably in a way that's loaded early and enforced
    "fish/conf.d/01-path-security.fish".text = ''
      # Set secure PATH and make it readonly
      set -gx PATH /run/wrappers/bin /run/current-system/sw/bin /usr/bin /bin

      # Add user paths in controlled manner
      for user_path in ~/.local/share/flatpak/exports/bin /var/lib/flatpak/exports/bin ~/.nix-profile/bin /nix/profile/bin ~/.local/state/nix/profile/bin /etc/profiles/per-user/(whoami)/bin /nix/var/nix/profiles/default/bin
        if test -d $user_path
          set -gx PATH $PATH $user_path
        end
      end

      # Create a function that validates and resets PATH if tampered
      function __enforce_path --on-event fish_preexec
        set -l expected_start "/run/wrappers/bin /run/current-system/sw/bin /usr/bin /bin"
        set -l actual_start (string join " " $PATH[1..4])

        if test "$actual_start" != "$expected_start"
          # PATH has been tampered with, reset it
          set -gx PATH /run/wrappers/bin /run/current-system/sw/bin /usr/bin /bin
          for user_path in ~/.local/share/flatpak/exports/bin /var/lib/flatpak/exports/bin ~/.nix-profile/bin /nix/profile/bin ~/.local/state/nix/profile/bin /etc/profiles/per-user/(whoami)/bin /nix/var/nix/profiles/default/bin
            if test -d $user_path
              set -gx PATH $PATH $user_path
            end
          end
        end
      end

      # Also enforce on prompt
      function __enforce_path_prompt --on-event fish_prompt
        __enforce_path
      end
    '';

    "fish/conf.d/02-validate-critical.fish".text = ''
      # Validate critical commands on interactive start
      function __validate_sudo --on-event fish_prompt
        set -l sudo_path (command -v sudo)
        if test "$sudo_path" != "/run/wrappers/bin/sudo"
          # Override sudo to use correct path
          function sudo --wraps=/run/wrappers/bin/sudo
            command /run/wrappers/bin/sudo $argv
          end
        end
      end
    '';

    "fish/conf.d/00-ensure-dir.fish".text = ''
      # This file ensures conf.d directory is managed by home-manager
    '';
  };
}
