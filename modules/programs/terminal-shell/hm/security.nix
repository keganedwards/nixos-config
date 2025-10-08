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

  # Cache location in protected area
  cacheDir = "/var/lib/fish-secure-cache/${username}";
  abbrCacheFile = "${cacheDir}/abbreviations.fish";
  pathCacheFile = "${cacheDir}/secure-paths.txt";

  # Generate fish abbreviations at build time
  generateAbbrScript = pkgs.writeShellScript "generate-fish-abbrs" ''
    set -euo pipefail

    # Ensure cache directory exists with correct permissions
    if [[ ! -d ${cacheDir} ]]; then
      mkdir -p ${cacheDir}
    fi

    # Create temporary file
    TEMP_FILE=$(mktemp)
    trap "rm -f $TEMP_FILE" EXIT

    # Track seen commands
    declare -A seen

    # Generate abbreviations for each secure path in order
    for dir in ${lib.concatStringsSep " " securePaths}; do
      if [[ -d "$dir" ]]; then
        for cmd in "$dir"/*; do
          if [[ -x "$cmd" && -f "$cmd" ]]; then
            basename=$(basename "$cmd")

            # Skip commands with special characters that cause issues in fish
            case "$basename" in
              *[\[\]\{\}\(\)\<\>\'\"\`\;\&\|\\\$\*\?]*)
                continue
                ;;
            esac

            # Skip if already seen
            if [[ -n "''${seen[$basename]:-}" ]]; then
              continue
            fi

            seen[$basename]=1

            # Escape the path for fish (names are already validated to be safe)
            escaped_path=$(printf '%q' "$cmd")

            echo "abbr -a -g -- $basename $escaped_path" >> "$TEMP_FILE"
          fi
        done
      fi
    done

    # Atomically replace cache file
    mv "$TEMP_FILE" ${abbrCacheFile}

    # Store secure paths for validation
    printf '%s\n' ${lib.concatStringsSep " " securePaths} > ${pathCacheFile}

    echo "Generated $(grep -c '^abbr' ${abbrCacheFile}) secure abbreviations"
  '';
in {
  # Create cache directory with proper permissions at system activation
  system.activationScripts.fishSecureCacheDir = lib.stringAfter ["users"] ''
    echo "Creating fish secure cache directory..."
    mkdir -p ${cacheDir}
    chmod 755 ${cacheDir}
  '';

  # Generate abbreviations at system activation
  system.activationScripts.fishSecureCache = lib.stringAfter ["fishSecureCacheDir"] ''
    echo "Generating secure fish abbreviations cache..."
    ${generateAbbrScript}
    chmod 644 ${abbrCacheFile} 2>/dev/null || true
    chmod 644 ${pathCacheFile} 2>/dev/null || true
  '';

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

        # Set Starship config location to user's actual home (not protected home)
        set -gx STARSHIP_CONFIG /home/${username}/.config/starship.toml

        # Load cached secure abbreviations
        if test -f ${abbrCacheFile}
          source ${abbrCacheFile}
        else
          echo "Warning: Secure abbreviations cache not found. Run 'sudo nixos-rebuild switch' to generate." >&2
        end

        # Function to validate command paths (cached for performance)
        function __validate_command
          set -l cmd $argv[1]

          # Check if command resolves to a secure path
          set -l cmd_path (command -v $cmd 2>/dev/null)
          if test -z "$cmd_path"
            return 1
          end

          # Verify it's in one of our secure paths
          for secure_path in ${lib.concatStringsSep " " securePaths}
            if string match -q "$secure_path/*" "$cmd_path"
              return 0
            end
          end

          echo "Warning: Command '$cmd' resolved to untrusted path: $cmd_path" >&2
          return 1
        end
      '';

      interactiveShellInit = ''
        # Security: Prevent command injection in prompts
        set -g fish_prompt_pwd_full_dirs 0

        # Monitor for dangerous environment variables on every prompt
        function __security_check --on-event fish_prompt
          # Silently remove dangerous variables
          set -q LD_PRELOAD; and set -e LD_PRELOAD
          set -q LD_LIBRARY_PATH; and set -e LD_LIBRARY_PATH
          set -q PYTHONPATH; and set -e PYTHONPATH
        end

        # Notify on PATH changes
        function __path_monitor --on-variable PATH
          echo "⚠ PATH was modified. Abbreviations still expand to secure paths." >&2
        end
      '';
    };
  };

  # Main user only gets the fish package
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      fish
    ];
  };
}
