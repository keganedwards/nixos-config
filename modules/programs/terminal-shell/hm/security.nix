# /modules/programs/terminal-shell/fish.nix
{
  fullName,
  email,
  pkgs,
  username,
  lib,
  ...
}: let
  protectedUsername = "protect-${username}";

  # Define the secure path order
  securePaths = [
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
  ];

  # Generate abbreviations for all executables in secure paths
  generateSecureAbbreviations = ''
    # Function to find command in secure paths
    function __secure_which
      set -l cmd $argv[1]
      for dir in ${lib.concatStringsSep " " securePaths}
        if test -x "$dir/$cmd"
          echo "$dir/$cmd"
          return 0
        end
      end
      return 1
    end

    # Generate abbreviations for all commands in secure paths
    # This runs once at shell startup
    function __generate_secure_abbrs
      # Clear any existing abbreviations first
      for abbr in (abbr --list)
        abbr --erase $abbr
      end

      # Track what we've already created abbreviations for
      set -l seen_commands

      # Go through each secure path in order
      for dir in ${lib.concatStringsSep " " securePaths}
        if test -d "$dir"
          for cmd in (command ls -1 "$dir" 2>/dev/null)
            # Skip if we've already seen this command
            if contains $cmd $seen_commands
              continue
            end

            # Skip if it's not executable
            if not test -x "$dir/$cmd"
              continue
            end

            # Create abbreviation that expands to full path
            abbr --add --global $cmd "$dir/$cmd"
            set -a seen_commands $cmd
          end
        end
      end

      echo "Generated "(count $seen_commands)" secure command abbreviations"
    end

    # Generate abbreviations on startup
    __generate_secure_abbrs
  '';
in {
  # Protected user owns all fish configuration
  home-manager.users.${protectedUsername} = {
    programs.fish = {
      enable = true;

      shellInit = ''
        # Clear potentially dangerous environment variables
        set -e LD_PRELOAD
        set -e LD_LIBRARY_PATH
        set -e PYTHONPATH

        # Set protected environment variables
        set -gx GIT_AUTHOR_NAME "${fullName}"
        set -gx GIT_AUTHOR_EMAIL "${email}"
        set -gx GIT_COMMITTER_NAME "${fullName}"
        set -gx GIT_COMMITTER_EMAIL "${email}"

        ${generateSecureAbbreviations}
      '';

      interactiveShellInit = ''
        # Security: Prevent command injection in prompts
        set -g fish_prompt_pwd_full_dirs 0

        # Monitor for LD_PRELOAD and similar on every prompt
        function __security_check --on-event fish_prompt
          # Silently remove dangerous variables
          set -q LD_PRELOAD; and set -e LD_PRELOAD
          set -q LD_LIBRARY_PATH; and set -e LD_LIBRARY_PATH
        end

        # Notify on PATH changes
        function __path_monitor --on-variable PATH
          echo "⚠ PATH was modified. Abbreviations still expand to secure paths." >&2
        end
      '';

      functions = {
        check-security = {
          description = "Check current security settings";
          body = ''
            echo "Security Check:"
            echo "==============="

            # Check dangerous variables
            if set -q LD_PRELOAD
              echo "✗ LD_PRELOAD is set: $LD_PRELOAD"
              set -e LD_PRELOAD
              echo "  → Removed LD_PRELOAD"
            else
              echo "✓ LD_PRELOAD is not set"
            end

            if set -q LD_LIBRARY_PATH
              echo "✗ LD_LIBRARY_PATH is set: $LD_LIBRARY_PATH"
              set -e LD_LIBRARY_PATH
              echo "  → Removed LD_LIBRARY_PATH"
            else
              echo "✓ LD_LIBRARY_PATH is not set"
            end

            # Show abbreviation status
            echo ""
            set -l abbr_count (abbr --list | wc -l)
            echo "✓ $abbr_count secure command abbreviations active"

            # Show current PATH for reference
            echo ""
            echo "Current PATH (abbreviations bypass this):"
            echo $PATH | tr ':' '\n' | sed 's/^/  /'

            echo ""
            echo "Type any command and press SPACE to see it expand to secure path"
          '';
        };

        refresh-abbrs = {
          description = "Regenerate secure command abbreviations";
          body = ''
            echo "Refreshing secure abbreviations..."
            __generate_secure_abbrs
          '';
        };

        show-abbr = {
          description = "Show what a command abbreviates to";
          body = ''
            for cmd in $argv
              set -l expansion (abbr --show $cmd 2>/dev/null)
              if test -n "$expansion"
                echo "$cmd → $expansion"
              else
                echo "$cmd has no abbreviation"
              end
            end
          '';
        };
      };
    };
  };

  # Main user only gets the fish package
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      fish
    ];
  };
}
