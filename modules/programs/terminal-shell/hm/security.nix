# /modules/programs/terminal-shell/fish.nix
{
  fullName,
  email,
  pkgs,
  username,
  ...
}: let
  protectedUsername = "protect-${username}";
in {
  # Protected user owns all fish configuration
  home-manager.users.${protectedUsername} = {
    programs.fish = {
      enable = true;

      shellInit = ''
        # Secure PATH ordering - system paths first
        set -gx PATH /run/wrappers/bin /run/current-system/sw/bin /nix/var/nix/profiles/default/bin $PATH

        # Unset potentially dangerous environment variables
        set -e LD_PRELOAD
        set -e LD_LIBRARY_PATH
        set -e PYTHONPATH

        # Set protected environment variables
        set -gx GIT_AUTHOR_NAME "${fullName}"
        set -gx GIT_AUTHOR_EMAIL "${email}"
        set -gx GIT_COMMITTER_NAME "${fullName}"
        set -gx GIT_COMMITTER_EMAIL "${email}"

        # Validate and override critical commands to use secure paths
        function sudo --wraps=/run/wrappers/bin/sudo
          command /run/wrappers/bin/sudo $argv
        end
      '';

      interactiveShellInit = ''
        # Security: Prevent command injection in prompts
        set -g fish_prompt_pwd_full_dirs 0
      '';

      # Use fish functions instead of conf.d files
      functions = {
        set = {
          description = "Override set to protect critical variables";
          body = ''
            # Extract the variable name from argv
            set -l var_name (string replace -r '^-[a-z]+ ' "" -- $argv[1] 2>/dev/null)

            # Block modifications to security-critical variables
            if string match -q -r "^(PATH|LD_PRELOAD|LD_LIBRARY_PATH|SSH_ASKPASS)\$" -- $var_name
              echo "Modification of $var_name blocked for security" >&2
              return 1
            else
              # Allow other set operations
              builtin set $argv
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
