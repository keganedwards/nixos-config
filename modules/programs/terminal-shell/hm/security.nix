{
  fullName,
  email,
  ...
}: {
  programs.fish = {
    shellInit = ''
      # Unset potentially dangerous environment variables
      set -e LD_PRELOAD
      set -e LD_LIBRARY_PATH
      set -e PYTHONPATH

      # Set protected environment variables
      set -gx GIT_AUTHOR_NAME "${fullName}"
      set -gx GIT_AUTHOR_EMAIL "${email}"
      set -gx GIT_COMMITTER_NAME "${fullName}"
      set -gx GIT_COMMITTER_EMAIL "${email}"

      # Validate critical commands
      set -l sudo_path (command -v sudo 2>/dev/null)
      if test -n "$sudo_path"; and test "$sudo_path" != "/run/wrappers/bin/sudo"
        # Override sudo to use correct path
        function sudo --wraps=/run/wrappers/bin/sudo
          command /run/wrappers/bin/sudo $argv
        end
      end
    '';

    interactiveShellInit = ''
      # Security: Prevent command injection in prompts
      set -g fish_prompt_pwd_full_dirs 0
    '';
  };

  # Override the set command to prevent PATH tampering
  xdg.configFile."fish/functions/set.fish".text = ''
    function set --description 'Override set to protect PATH'
      # Check if trying to modify PATH
      if string match -q "*PATH*" -- $argv
        echo "PATH modification blocked for security" >&2
        return 1
      else
        # Allow other set operations
        builtin set $argv
      end
    end
  '';
}
