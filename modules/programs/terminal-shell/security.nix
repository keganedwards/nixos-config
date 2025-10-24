{
  fullName,
  email,
  pkgs,
  username,
  lib,
  config,
  ...
}: let
  protectedUsername = "protect-${username}";

  securePaths = [
    "/run/wrappers/bin"
    "/run/current-system/sw/bin"
    "/nix/var/nix/profiles/default/bin"
  ];

  cacheDir = "/var/lib/fish-secure-cache/${username}";
  abbrCacheFile = "${cacheDir}/abbreviations.fish";
  pathCacheFile = "${cacheDir}/secure-paths.txt";

  aliasesToExclude =
    (lib.attrNames config.home-manager.users.${protectedUsername}.programs.fish.shellAliases)
    ++ ["nix-shell"];

  generateAbbrScript = pkgs.writeShellScript "generate-fish-abbrs" ''
    set -euo pipefail

    if [[ ! -d ${cacheDir} ]]; then
      mkdir -p ${cacheDir}
    fi

    TEMP_FILE=$(mktemp)
    trap "rm -f $TEMP_FILE" EXIT

    declare -A seen
    declare -a excluded_aliases=(${lib.concatStringsSep " " aliasesToExclude})

    is_excluded() {
      local cmd_basename="''${1}"
      for excluded in "''${excluded_aliases[@]}"; do
        if [[ "$cmd_basename" == "$excluded" ]]; then
          return 0
        fi
      done
      return 1
    }

    for dir in ${lib.concatStringsSep " " securePaths}; do
      if [[ -d "$dir" ]]; then
        for cmd in "$dir"/*; do
          if [[ -x "$cmd" && -f "$cmd" ]]; then
            basename=$(basename "$cmd")

            case "$basename" in
              *[\[\]\{\}\(\)\<\>\'\"\`\;\&\|\\\$\*\?]*)
                continue
                ;;
            esac

            if [[ -n "''${seen[$basename]:-}" ]]; then
              continue
            fi

            seen[$basename]=1

            if is_excluded "$basename"; then
              continue
            fi

            escaped_path=$(printf '%q' "$cmd")
            echo "abbr -a -g -- $basename $escaped_path" >> "$TEMP_FILE"
          fi
        done
      fi
    done

    mv "$TEMP_FILE" ${abbrCacheFile}
    printf '%s\n' ${lib.concatStringsSep " " securePaths} > ${pathCacheFile}
    echo "Generated $(grep -c '^abbr' ${abbrCacheFile}) secure abbreviations"
  '';
in {
  system.activationScripts.fishSecureCacheDir = lib.stringAfter ["users"] ''
    mkdir -p ${cacheDir}
    chmod 755 ${cacheDir}
  '';

  system.activationScripts.fishSecureCache = lib.stringAfter ["fishSecureCacheDir"] ''
    ${generateAbbrScript}
    chmod 644 ${abbrCacheFile} 2>/dev/null || true
    chmod 644 ${pathCacheFile} 2>/dev/null || true
  '';

  home-manager.users.${protectedUsername} = {
    programs.fish = {
      enable = true;

      shellInit = ''
        set -e LD_PRELOAD
        set -e LD_LIBRARY_PATH
        set -e PYTHONPATH
        set -gx GIT_AUTHOR_NAME "${fullName}"
        set -gx GIT_AUTHOR_EMAIL "${email}"
        set -gx GIT_COMMITTER_NAME "${fullName}"
        set -gx GIT_COMMITTER_EMAIL "${email}"
        set -gx STARSHIP_CONFIG /home/${username}/.config/starship.toml

        if test -f ${abbrCacheFile}
          source ${abbrCacheFile}
        else
          echo "Warning: Secure abbreviations cache not found. Run 'sudo nixos-rebuild switch' to generate." >&2
        end

        function __validate_command
          set -l cmd $argv[1]
          set -l cmd_path (command -v $cmd 2>/dev/null)
          if test -z "$cmd_path"
            return 1
          end

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
        set -g fish_prompt_pwd_full_dirs 0

        function __security_check --on-event fish_prompt
          set -q LD_PRELOAD; and set -e LD_PRELOAD
          set -q LD_LIBRARY_PATH; and set -e LD_LIBRARY_PATH
          set -q PYTHONPATH; and set -e PYTHONPATH
        end

        function __path_monitor --on-variable PATH
          echo "⚠ PATH was modified. Abbreviations still expand to secure paths." >&2
        end
      '';
    };
  };

  home-manager.users.${username} = {
    home.packages = with pkgs; [
      fish
    ];
  };
}
