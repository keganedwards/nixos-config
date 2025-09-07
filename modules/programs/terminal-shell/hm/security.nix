# /modules/programs/terminal-shell/hm/security.nix
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
    '';
  };

  # Single conf.d file for PATH security
  xdg.configFile."fish/conf.d/01-path-security.fish".text = ''
    # Clean and secure PATH ordering
    set -l clean_paths
    for path in $PATH
      if test -n "$path"; and not string match -q "./*" "$path"; and not string match -q "../*" "$path"; and test "$path" != "."
        set clean_paths $clean_paths $path
      end
    end

    # Prioritize secure, root-owned paths
    set -l secure_priority_paths /run/wrappers/bin /run/current-system/sw/bin /usr/bin /bin

    for secure_path in $secure_priority_paths
      set clean_paths (string match -v $secure_path $clean_paths)
    end

    set -gx PATH $secure_priority_paths $clean_paths
  '';

  # Ensure conf.d directory exists
  xdg.configFile."fish/conf.d/00-ensure-dir.fish".text = ''
    # This file ensures conf.d directory is managed by home-manager
  '';
}
