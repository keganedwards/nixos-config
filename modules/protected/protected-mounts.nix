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

  # Files to exclude from mounting
  excludeFiles = [
    ".config/environment.d/10-home-manager.conf"
    ".config/systemd/user/tray.target"
    ".config/user-dirs.conf"
    ".config/user-dirs.dirs"
    ".config/user-dirs.locale"
  ];

  # Directories that should be fully read-only (mounted as complete directories)
  fullyProtectedDirs = [
    ".config/fish/conf.d"
    ".config/fish/functions"
  ];

  mountScript = pkgs.writeShellScript "mount-protected" ''
    set -euo pipefail
    export PATH="${pkgs.util-linux}/bin:${pkgs.coreutils}/bin:${pkgs.e2fsprogs}/bin:${pkgs.fd}/bin:${pkgs.findutils}/bin:${pkgs.gawk}/bin:${pkgs.gnugrep}/bin:$PATH"

    exec 200>"${lockFile}"
    if ! flock -w 10 -x 200; then
      echo "Failed to acquire lock" >&2
      exit 1
    fi
    trap 'flock -u 200' EXIT

    echo "Starting protected mounts for ${username}..."

    # Get the current home-manager generation for protected user
    HM_GENERATION="${protectedHome}/.local/state/home-manager/gcroots/current-home"
    if [ ! -L "$HM_GENERATION" ]; then
      echo "No home-manager generation found for ${protectedUsername}" >&2
      exit 1
    fi

    GENERATION_PATH=$(readlink -f "$HM_GENERATION")
    echo "Using generation: $GENERATION_PATH"

    # Function to check exclusions
    is_excluded() {
      local file="$1"
      case "$file" in
        ${lib.concatMapStringsSep "\n        " (f: "${f}) return 0 ;;") excludeFiles}
        *) return 1 ;;
      esac
    }

    # Function to check if file is in a fully protected directory
    is_in_fully_protected() {
      local file="$1"
      for pdir in ${lib.concatStringsSep " " (map (d: "\"${d}\"") fullyProtectedDirs)}; do
        if [[ "$file" == "$pdir"/* ]] || [[ "$file" == "$pdir" ]]; then
          return 0
        fi
      done
      return 1
    }

    # Phase 1: Clean existing state
    echo "Phase 1: Cleaning existing state..."

    # Remove immutable attributes (limit scope for performance)
    if [ -d "${targetHome}" ]; then
      find "${targetHome}" -maxdepth 5 \( -type f -o -type d \) 2>/dev/null | while read -r item; do
        chattr -i "$item" 2>/dev/null || true
      done &
      wait
    fi

    # Unmount all mounts (reverse order)
    if mount | grep -F "${targetHome}/" >/dev/null 2>&1; then
      mount | grep -F "${targetHome}/" | awk '{print $3}' | tac | while read -r mp; do
        umount -l "$mp" 2>/dev/null || true
      done
    fi

    # Short sleep to ensure unmounts complete
    sleep 0.5

    echo "  ✓ Clean slate"

    # Phase 2: Discover and categorize files
    echo "Phase 2: Discovering files..."

    declare -A files_by_dir=()
    declare -A all_dirs=()
    declare -A dir_mount_counts=()

    if [ ! -d "$GENERATION_PATH/home-files" ]; then
      echo "No home-files directory found" >&2
      exit 1
    fi

    cd "$GENERATION_PATH/home-files"

    # Collect all files and group by directory
    while IFS= read -r file; do
      rel_path="''${file#./}"

      # Skip excluded files
      is_excluded "$rel_path" && continue

      # Skip files in fully protected directories (we'll handle those separately)
      is_in_fully_protected "$rel_path" && continue

      # Verify it's a file or symlink to file
      if [ -L "$file" ]; then
        target=$(readlink -f "$file" 2>/dev/null || true)
        [ -f "$target" ] || continue
      elif [ ! -f "$file" ]; then
        continue
      fi

      # Track file and its directory
      dir_path=$(dirname "$rel_path")
      files_by_dir["$dir_path"]+="$rel_path"$'\n'

      # Track all parent directories
      current="$dir_path"
      while [[ "$current" != "." ]]; do
        all_dirs["$current"]=1
        current=$(dirname "$current")
      done

      # Count files per directory
      dir_mount_counts["$dir_path"]=$((''${dir_mount_counts["$dir_path"]:-0} + 1))
    done < <(fd --type f --type l --hidden --no-ignore . . 2>/dev/null || find . -type f -o -type l)

    total_files=0
    for dir in "''${!dir_mount_counts[@]}"; do
      total_files=$((total_files + ''${dir_mount_counts["$dir"]}))
    done

    echo "  ✓ Found $total_files files across ''${#files_by_dir[@]} directories"

    # Phase 3: Create directory structure
    echo "Phase 3: Creating directory structure..."

    for dir in "''${!all_dirs[@]}"; do
      dir_path="${targetHome}/$dir"
      if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path"
        chown ${username}:users "$dir_path"
        chmod 755 "$dir_path"
      fi
    done

    echo "  ✓ Directory structure ready"

    # Phase 4: Bind mount directories to prevent moving them
    echo "Phase 4: Protecting directory structure..."

    # Sort directories by depth (mount parents first)
    mapfile -t sorted_dirs < <(
      for dir in "''${!all_dirs[@]}"; do
        echo "$dir"
      done | awk -F/ '{print NF-1, $0}' | sort -n | cut -d' ' -f2-
    )

    declare -A bind_mounted_dirs=()

    for rel_dir in "''${sorted_dirs[@]}"; do
      dir_path="${targetHome}/$rel_dir"

      # Skip if a parent is already bind mounted
      skip=false
      parent="$rel_dir"
      while [[ "$parent" != "." ]]; do
        parent=$(dirname "$parent")
        if [[ -n "''${bind_mounted_dirs[$parent]:-}" ]]; then
          skip=true
          break
        fi
      done
      [ "$skip" = true ] && continue

      # Skip if it doesn't contain any files
      if [[ -z "''${dir_mount_counts[$rel_dir]:-}" ]]; then
        has_subdirs_with_files=false
        for check_dir in "''${!dir_mount_counts[@]}"; do
          if [[ "$check_dir" == "$rel_dir/"* ]]; then
            has_subdirs_with_files=true
            break
          fi
        done
        [ "$has_subdirs_with_files" = false ] && continue
      fi

      # Bind mount the directory to itself
      if mount --bind "$dir_path" "$dir_path" 2>/dev/null; then
        bind_mounted_dirs["$rel_dir"]=1
      fi
    done

    echo "  ✓ Protected ''${#bind_mounted_dirs[@]} directories from moving"

    # Phase 5: Mount individual files
    echo "Phase 5: Mounting protected files..."

    mount_count=0
    failed_count=0

    for dir in "''${!files_by_dir[@]}"; do
      while IFS= read -r rel_path; do
        [ -z "$rel_path" ] && continue

        src="$GENERATION_PATH/home-files/$rel_path"
        dst="${targetHome}/$rel_path"

        # Resolve source
        if [ -L "$src" ]; then
          resolved=$(readlink -f "$src" 2>/dev/null || echo "$src")
        else
          resolved="$src"
        fi

        [ -f "$resolved" ] || continue

        # Remove existing file
        if [ -e "$dst" ]; then
          chattr -i "$dst" 2>/dev/null || true
          rm -f "$dst" 2>/dev/null || true
        fi

        # Create mount point
        touch "$dst" 2>/dev/null || {
          echo "  ⚠ Cannot create: $dst"
          failed_count=$((failed_count + 1))
          continue
        }

        chown ${username}:users "$dst"
        chmod 644 "$dst"

        # Mount file read-only
        if mount --bind "$resolved" "$dst" 2>/dev/null && \
           mount -o remount,ro,bind "$dst" 2>/dev/null; then
          chattr +i "$dst" 2>/dev/null || true
          mount_count=$((mount_count + 1))
        else
          echo "  ⚠ Failed to mount: $dst"
          rm -f "$dst" 2>/dev/null || true
          failed_count=$((failed_count + 1))
        fi
      done <<< "''${files_by_dir[$dir]}"
    done

    echo "  ✓ Mounted $mount_count files ($failed_count failed)"

    # Phase 6: Mount fully protected directories as read-only
    echo "Phase 6: Mounting fully protected directories..."

    protected_dir_count=0

    for pdir in ${lib.concatStringsSep " " (map (d: "\"${d}\"") fullyProtectedDirs)}; do
      src_dir="$GENERATION_PATH/home-files/$pdir"
      dst_dir="${targetHome}/$pdir"

      # Ensure parent directory exists and is writable
      parent_dir=$(dirname "$dst_dir")
      if [ ! -d "$parent_dir" ]; then
        mkdir -p "$parent_dir"
        chown ${username}:users "$parent_dir"
        chmod 755 "$parent_dir"
      fi

      # Check if source directory exists
      if [ ! -d "$src_dir" ]; then
        echo "  ⚠ Source directory doesn't exist: $pdir"
        continue
      fi

      # Clean up existing destination
      if [ -e "$dst_dir" ]; then
        # Remove immutable flags
        find "$dst_dir" \( -type f -o -type d \) 2>/dev/null | tac | while read -r item; do
          chattr -i "$item" 2>/dev/null || true
        done
        chattr -i "$dst_dir" 2>/dev/null || true

        # Unmount if mounted
        if mountpoint -q "$dst_dir" 2>/dev/null; then
          umount -l "$dst_dir" 2>/dev/null || true
        fi

        # Remove directory
        rm -rf "$dst_dir" 2>/dev/null || true
      fi

      # Create mount point directory
      mkdir -p "$dst_dir"
      chown ${username}:users "$dst_dir"
      chmod 755 "$dst_dir"

      # Bind mount the entire source directory
      if mount --bind "$src_dir" "$dst_dir" 2>/dev/null; then
        # Remount as read-only
        if mount -o remount,ro,bind "$dst_dir" 2>/dev/null; then
          echo "  ✓ Directory mounted read-only: $pdir ($(find "$dst_dir" -type f 2>/dev/null | wc -l) files)"

          # Make directory immutable to prevent unmounting
          chattr +i "$dst_dir" 2>/dev/null || true
          protected_dir_count=$((protected_dir_count + 1))
        else
          echo "  ⚠ Failed to remount read-only: $pdir"
          umount -l "$dst_dir" 2>/dev/null || true
        fi
      else
        echo "  ⚠ Failed to bind mount: $pdir"
        rm -rf "$dst_dir" 2>/dev/null || true
      fi
    done

    echo "  ✓ Protected $protected_dir_count directories as read-only"

    # Phase 7: Summary
    echo "Phase 7: Protection summary..."
    echo "  Individual files mounted: $mount_count"
    echo "  Fully protected directories: $protected_dir_count"

    # Verify fully protected directories
    for pdir in ${lib.concatStringsSep " " (map (d: "\"${d}\"") fullyProtectedDirs)}; do
      dst_dir="${targetHome}/$pdir"
      if mountpoint -q "$dst_dir" 2>/dev/null; then
        if mount | grep -F "$dst_dir" | grep -q "ro,"; then
          echo "  ✓ $pdir is read-only and accessible"
        else
          echo "  ⚠ $pdir is mounted but may not be read-only"
        fi
      else
        echo "  ⚠ $pdir is not mounted"
      fi
    done

    echo "Protected mounts completed successfully"
  '';

  unmountScript = pkgs.writeShellScript "unmount-protected" ''
    set -euo pipefail
    export PATH="${pkgs.util-linux}/bin:${pkgs.coreutils}/bin:${pkgs.e2fsprogs}/bin:${pkgs.fd}/bin:${pkgs.findutils}/bin:${pkgs.gawk}/bin:${pkgs.gnugrep}/bin:$PATH"

    exec 200>"${lockFile}"
    if ! flock -w 10 -x 200; then
      echo "Failed to acquire lock" >&2
      exit 1
    fi
    trap 'flock -u 200' EXIT

    echo "Unmounting protected files..."

    # Remove immutable attributes from target home
    if [ -d "${targetHome}" ]; then
      find "${targetHome}" -maxdepth 5 \( -type f -o -type d \) 2>/dev/null | while read -r item; do
        chattr -i "$item" 2>/dev/null || true
      done
    fi

    # Unmount all mounts in reverse order
    if mount | grep -F "${targetHome}/" >/dev/null 2>&1; then
      mount | grep -F "${targetHome}/" | awk '{print $3}' | tac | while read -r mp; do
        umount -l "$mp" 2>/dev/null || true
      done
    fi

    echo "Unmount completed"
  '';
in {
  environment.systemPackages = with pkgs; [
    fd
    util-linux
    e2fsprogs
    findutils
    gawk
    gnugrep
  ];

  systemd.tmpfiles.rules = [
    "d ${protectedHome} 0755 ${protectedUsername} protected-users -"
    "f ${lockFile} 0644 root root -"
  ];

  systemd.services = {
    "protected-mount-${username}" = {
      description = "Mount protected files for ${username}";
      wantedBy = ["multi-user.target"];

      after = [
        "home-manager-${protectedUsername}.service"
        "home-manager-${username}.service"
      ];

      before = [
        "display-manager.service"
        "getty@tty1.service"
      ];

      wants = [
        "home-manager-${protectedUsername}.service"
        "home-manager-${username}.service"
      ];

      unitConfig = {
        RequiresMountsFor = [protectedHome targetHome];
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${mountScript}";
        ExecReload = "${mountScript}";
        TimeoutStartSec = "120s";
        Restart = "no";
      };

      restartTriggers = [
        (builtins.toString (config.home-manager.users.${protectedUsername}.home.activationPackage or ""))
      ];

      reloadTriggers = [
        (builtins.toString (config.home-manager.users.${protectedUsername}.home.activationPackage or ""))
      ];
    };

    "protected-mount-${username}-cleanup" = {
      description = "Clean up protected mounts on shutdown";
      wantedBy = ["shutdown.target"];

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${unmountScript}";
        TimeoutStartSec = "30s";
        DefaultDependencies = false;
      };

      before = ["shutdown.target"];
    };
  };

  # Trigger the mount service on every system activation
  system.activationScripts."protected-mount-${username}-trigger" = lib.stringAfter ["users"] ''
    echo "Reloading protected mounts for ${username}..."
    ${pkgs.systemd}/bin/systemctl restart protected-mount-${username}.service || true
  '';
}
