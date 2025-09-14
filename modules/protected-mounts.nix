{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  protectedUsername = "protect-${username}";
  protectedHome = config.users.users.${protectedUsername}.home;
  targetHome = config.users.users.${username}.home;
  lockFile = "/var/run/protected-mounts-${username}.lock";

  # Directories to exclude from protection
  excludeDirs = [
    ".cache"
    ".local/state/home-manager"
    ".local/state/nix/profiles"
    ".nix-defexpr"
    ".nix-profile"
  ];

  # Specific files to exclude
  excludeFiles = [
    ".config/environment.d/10-home-manager.conf"
    ".config/systemd/user/tray.target"
    ".config/user-dirs.conf"
    ".config/user-dirs.dirs"
  ];

  # Directories that should be protected even if they contain files
  # These are directories where we want to prevent any modifications
  protectedDirs = [
    ".config/fish/conf.d"
    ".config/fish/functions"
  ];

  # Build exclude arguments for fd (only for directories)
  fdExcludeArgs = lib.concatMapStringsSep " " (dir: "-E '${dir}'") excludeDirs;

  mountScript = pkgs.writeShellScript "mount-protected" ''
    set -euo pipefail
    export PATH="${pkgs.util-linux}/bin:${pkgs.coreutils}/bin:${pkgs.e2fsprogs}/bin:${pkgs.fd}/bin:${pkgs.gawk}/bin:${pkgs.ripgrep}/bin:$PATH"

    exec 200>"${lockFile}"
    if ! flock -w 10 -x 200; then
      echo "Failed to acquire lock" >&2
      exit 1
    fi

    trap 'flock -u 200' EXIT

    echo "Starting protected mounts for ${username}..."

    if [ ! -d "${protectedHome}" ]; then
      echo "Protected home does not exist yet" >&2
      exit 1
    fi

    # Function to clean a path of all protection
    clean_path() {
      local path="$1"

      chattr -i "$path" 2>/dev/null || true

      if mountpoint -q "$path" 2>/dev/null; then
        local max_attempts=5
        local attempt=0

        while mountpoint -q "$path" 2>/dev/null && [ $attempt -lt $max_attempts ]; do
          umount "$path" 2>/dev/null || umount -l "$path" 2>/dev/null || true
          attempt=$((attempt + 1))
          [ $attempt -lt $max_attempts ] && sleep 0.1
        done

        if mountpoint -q "$path" 2>/dev/null; then
          umount -l "$path" 2>/dev/null || true
        fi
      fi

      chattr -i "$path" 2>/dev/null || true
    }

    # Check if a file should be excluded
    should_exclude() {
      local rel_path="$1"
      ${lib.concatMapStringsSep "\n" (file: ''
        [[ "$rel_path" == "${file}" ]] && return 0
      '')
      excludeFiles}
      return 1
    }

    # Check if a directory should be protected (made immutable)
    should_protect_dir() {
      local dir_path="$1"
      # Extract relative path
      local rel_dir="''${dir_path#${targetHome}/}"

      ${lib.concatMapStringsSep "\n" (dir: ''
        [[ "$rel_dir" == "${dir}" ]] && return 0
        [[ "$rel_dir" == "${dir}/"* ]] && return 0
      '')
      protectedDirs}
      return 1
    }

    # Check if a directory should be excluded from immutability
    should_exclude_dir() {
      local dir_path="$1"
      # Never make .config/environment.d immutable
      [[ "$dir_path" == *"/.config/environment.d" ]] && return 0
      # Never make .config immutable
      [[ "$dir_path" == *"/.config" ]] && return 0
      return 1
    }

    # Clean up excluded files first
    echo "Cleaning up excluded files..."
    ${lib.concatMapStringsSep "\n" (file: ''
        excluded_path="${targetHome}/${file}"
        if [ -e "$excluded_path" ]; then
          clean_path "$excluded_path"
        fi
      '')
      excludeFiles}

    # Discover all files from protected home - this gives us our complete list
    echo "Discovering files from protected home..."
    declare -a files_to_mount=()
    declare -a parent_dirs=()
    declare -A parent_dirs_set=()

    # Find all files including hidden ones
    while IFS= read -r file_path; do
      [ -z "$file_path" ] && continue

      # Get relative path
      rel_path="''${file_path#${protectedHome}/}"

      # Skip if this specific file is excluded
      should_exclude "$rel_path" && continue

      # Check if it's a symlink to nix store OR a regular file
      if [ -L "$file_path" ]; then
        # It's a symlink - check if it points to nix store
        target=$(readlink "$file_path" 2>/dev/null || true)
        if [[ "$target" == /nix/store/* ]]; then
          files_to_mount+=("$rel_path")
        fi
      elif [ -f "$file_path" ]; then
        # It's a regular file - include it
        files_to_mount+=("$rel_path")
      fi

      # Track parent directories for files we're mounting
      if [ "''${#files_to_mount[@]}" -gt 0 ] && [ "''${files_to_mount[-1]}" == "$rel_path" ]; then
        parent_dir=$(dirname "$rel_path")
        while [[ "$parent_dir" != "." ]]; do
          # Add to associative array for deduplication
          parent_dirs_set["$parent_dir"]=1
          parent_dir=$(dirname "$parent_dir")
        done
      fi
    done < <(fd --hidden --no-ignore --type f --type l ${fdExcludeArgs} . "${protectedHome}" 2>/dev/null)

    # Convert associative array keys to regular array
    parent_dirs=("''${!parent_dirs_set[@]}")

    echo "Found ''${#files_to_mount[@]} files to mount"

    # Clean up existing state - ONLY for paths we're managing
    echo "Cleaning up existing state..."

    # Clean all currently mounted files
    while IFS= read -r mount_point; do
      clean_path "$mount_point"
    done < <(mount | rg -F "${targetHome}/" | awk '{print $3}' || true)

    # Clean ONLY the parent directories we're about to use
    for parent in "''${parent_dirs[@]:-}"; do
      parent_path="${targetHome}/$parent"
      [ -d "$parent_path" ] && clean_path "$parent_path"
    done

    # Ensure parent directories exist
    echo "Setting up directory structure..."
    for parent in "''${parent_dirs[@]:-}"; do
      parent_path="${targetHome}/$parent"

      if [ ! -d "$parent_path" ]; then
        mkdir -p "$parent_path"
      fi

      clean_path "$parent_path"
      chown ${username}:users "$parent_path" 2>/dev/null || true
      chmod 755 "$parent_path" 2>/dev/null || true
    done

    # Mount all files
    echo "Mounting protected files..."
    mount_count=0

    for rel_path in "''${files_to_mount[@]:-}"; do
      src_path="${protectedHome}/$rel_path"
      dst_path="${targetHome}/$rel_path"

      # Resolve the path if it's a symlink, otherwise use as-is
      if [ -L "$src_path" ]; then
        resolved_src=$(readlink -f "$src_path" 2>/dev/null || echo "$src_path")
      else
        resolved_src="$src_path"
      fi

      if [ -f "$resolved_src" ]; then
        # Ensure destination is clean
        clean_path "$dst_path"

        # Create empty file with proper ownership FIRST
        rm -f "$dst_path" 2>/dev/null || true
        touch "$dst_path"
        chown ${username}:users "$dst_path"
        chmod 644 "$dst_path"

        # Mount and make read-only (atomic operation)
        if mount --bind "$resolved_src" "$dst_path" && mount -o remount,ro,bind "$dst_path"; then
          chattr +i "$dst_path" 2>/dev/null || true
          mount_count=$((mount_count + 1))
        else
          echo "  ! Failed: $rel_path" >&2
          umount "$dst_path" 2>/dev/null || true
          rm -f "$dst_path" 2>/dev/null || true
        fi
      fi
    done

    # Protect parent directories
    echo "Protecting parent directories..."
    for parent in "''${parent_dirs[@]:-}"; do
      parent_path="${targetHome}/$parent"

      # Check if this directory should be protected
      if should_protect_dir "$parent_path"; then
        chattr +i "$parent_path" 2>/dev/null && \
          echo "  ✓ Protected (forced): $parent" || \
          echo "  ⚠ Could not protect: $parent" >&2
        continue
      fi

      # Skip directories that should not be immutable
      if should_exclude_dir "$parent_path"; then
        echo "  ⊘ Skipping protection for: $parent (excluded)"
        continue
      fi

      # Check if directory contains any mounted files
      has_mounts=false
      for file in "$parent_path"/*; do
        if [ -f "$file" ] && mountpoint -q "$file" 2>/dev/null; then
          has_mounts=true
          break
        fi
      done

      if [ "$has_mounts" = true ]; then
        chattr +i "$parent_path" 2>/dev/null && \
          echo "  ✓ Protected: $parent" || \
          echo "  ⚠ Could not protect: $parent" >&2
      fi
    done

    echo "Protected mounts completed ($mount_count files mounted)"
  '';

  unmountScript = pkgs.writeShellScript "unmount-protected" ''
    set -euo pipefail
    export PATH="${pkgs.util-linux}/bin:${pkgs.coreutils}/bin:${pkgs.e2fsprogs}/bin:${pkgs.fd}/bin:${pkgs.gawk}/bin:${pkgs.ripgrep}/bin:$PATH"

    exec 200>"${lockFile}"
    if ! flock -w 10 -x 200; then
      echo "Failed to acquire lock" >&2
      exit 1
    fi

    trap 'flock -u 200' EXIT

    echo "Unmounting protected files..."

    clean_path() {
      local path="$1"

      chattr -i "$path" 2>/dev/null || true

      if mountpoint -q "$path" 2>/dev/null; then
        local max_attempts=5
        local attempt=0

        while mountpoint -q "$path" 2>/dev/null && [ $attempt -lt $max_attempts ]; do
          umount "$path" 2>/dev/null || umount -l "$path" 2>/dev/null || true
          attempt=$((attempt + 1))
          [ $attempt -lt $max_attempts ] && sleep 0.1
        done

        if mountpoint -q "$path" 2>/dev/null; then
          umount -l "$path" 2>/dev/null || true
        fi
      fi

      chattr -i "$path" 2>/dev/null || true
    }

    # Get all currently mounted paths under target home
    echo "Collecting mounted paths..."
    declare -a mounted_paths=()
    declare -A parent_dirs_set=()

    while IFS= read -r mount_point; do
      mounted_paths+=("$mount_point")

      # Track parent directories
      parent_dir=$(dirname "$mount_point")
      while [[ "$parent_dir" != "${targetHome}" && "$parent_dir" != "/" ]]; do
        parent_dirs_set["$parent_dir"]=1
        parent_dir=$(dirname "$parent_dir")
      done
    done < <(mount | rg -F "${targetHome}/" | awk '{print $3}' || true)

    # Remove immutable attribute from all parent directories first
    echo "Removing directory immutability..."
    for parent_dir in "''${!parent_dirs_set[@]}"; do
      [ -d "$parent_dir" ] && chattr -i "$parent_dir" 2>/dev/null || true
    done

    # Clean excluded files
    ${lib.concatMapStringsSep "\n" (file: ''
        excluded_path="${targetHome}/${file}"
        [ -e "$excluded_path" ] && clean_path "$excluded_path"
      '')
      excludeFiles}

    # Clean all mounted files
    echo "Unmounting files..."
    for mount_point in "''${mounted_paths[@]:-}"; do
      clean_path "$mount_point"
    done

    echo "Unmount completed"
  '';
in {
  # Add required packages to system
  environment.systemPackages = with pkgs; [
    fd
    util-linux # for mount/umount
    e2fsprogs # for chattr
    gawk # for awk
    ripgrep # for rg (faster grep)
  ];

  systemd.tmpfiles.rules = [
    "d ${protectedHome} 0755 ${protectedUsername} protected-users -"
    "f ${lockFile} 0644 root root -"
  ];

  systemd.services = {
    "protected-mount-${username}" = {
      description = "Mount protected files for ${username}";
      # Start as early as possible but after filesystems
      wantedBy = ["multi-user.target"];

      # Run AFTER both home-manager services complete but BEFORE user sessions
      after = [
        "home-manager-${protectedUsername}.service"
        "home-manager-${username}.service"
      ];

      # Must run before display manager and user services
      before = [
        "display-manager.service"
        "getty@tty1.service"
        "user@${toString config.users.users.${username}.uid}.service"
      ];

      # Use Wants instead of Requisite to avoid blocking
      wants = [
        "home-manager-${protectedUsername}.service"
        "home-manager-${username}.service"
      ];

      unitConfig = {
        RequiresMountsFor = [protectedHome targetHome];
        # Ensure this completes before user can login
        DefaultDependencies = "no";
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # Clean up before mounting
        ExecStartPre = [
          "${unmountScript}"
          "${pkgs.coreutils}/bin/sleep 0.5"
        ];
        ExecStart = "${mountScript}";
        TimeoutStartSec = "60s";
        # Ensure service fails cleanly if something goes wrong
        Restart = "no";
      };

      restartTriggers = [
        mountScript
        unmountScript
        (builtins.toString (config.home-manager.users.${protectedUsername}.home.activationPackage or ""))
      ];
    };

    # Cleanup service with increased timeout
    "protected-mount-${username}-cleanup" = {
      description = "Clean up failed protected mounts for ${username}";

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${unmountScript}";
        TimeoutStartSec = "90s";
      };
    };
  };

  # Add a system activation script to clean up before rebuild
  system.activationScripts."protected-unmount-${username}" = lib.stringAfter ["users"] ''
    echo "Cleaning up protected mounts before activation..."
    ${unmountScript} || true
  '';
}
