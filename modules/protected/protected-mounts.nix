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

  # Directories that should be fully read-only (no writes at all)
  fullyProtectedDirs = [
    ".config/fish/conf.d"
    ".config/fish/functions"
  ];

  mountScript = pkgs.writeShellScript "mount-protected" ''
    set -euo pipefail
    export PATH="${pkgs.util-linux}/bin:${pkgs.coreutils}/bin:${pkgs.e2fsprogs}/bin:${pkgs.fd}/bin:${pkgs.findutils}/bin:${pkgs.gawk}/bin:${pkgs.ripgrep}/bin:$PATH"

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

    # Phase 1: Clean existing state
    echo "Phase 1: Cleaning existing state..."

    # Remove all immutable attributes
    fd --hidden --no-ignore --type f --type d . "${targetHome}" --exec-batch chattr -i {} 2>/dev/null \; || true
    chattr -i "${targetHome}" 2>/dev/null || true

    # Unmount all mounts (reverse order)
    mount | rg -F "${targetHome}/" | awk '{print $3}' | tac | while read -r mp; do
      umount -l "$mp" 2>/dev/null || true
    done

    echo "  ✓ Clean slate"

    # Phase 2: Discover and categorize files
    echo "Phase 2: Discovering files..."

    declare -A files_by_dir=()  # Map directory -> files in it
    declare -A all_dirs=()       # All directories that need to exist
    declare -A dir_mount_counts=() # Track how many files each dir will have
    declare -A fully_protected_map=() # Track which dirs are fully protected

    if [ ! -d "$GENERATION_PATH/home-files" ]; then
      echo "No home-files directory found" >&2
      exit 1
    fi

    cd "$GENERATION_PATH/home-files"

    # Mark fully protected directories
    for pdir in ${lib.concatStringsSep " " (map (d: "\"${d}\"") fullyProtectedDirs)}; do
      fully_protected_map["$pdir"]=1
    done

    # Collect all files and group by directory
    while IFS= read -r file; do
      rel_path="''${file#./}"

      # Skip excluded files
      is_excluded "$rel_path" && continue

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
    done < <(fd --type f --type l --hidden --no-ignore . .)

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

    # Also ensure fully protected dirs exist
    for pdir in ${lib.concatStringsSep " " (map (d: "\"${d}\"") fullyProtectedDirs)}; do
      dir_path="${targetHome}/$pdir"
      if [ ! -d "$dir_path" ]; then
        mkdir -p "$dir_path"
        chown ${username}:users "$dir_path"
        chmod 755 "$dir_path"
      fi
      all_dirs["$pdir"]=1
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

      # Skip if it doesn't contain any files and isn't fully protected
      if [[ -z "''${dir_mount_counts[$rel_dir]:-}" ]] && [[ -z "''${fully_protected_map[$rel_dir]:-}" ]]; then
        # Check if any subdirectory has files
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
      # This prevents the directory from being moved/renamed
      if mount --bind "$dir_path" "$dir_path" 2>/dev/null; then
        bind_mounted_dirs["$rel_dir"]=1
        echo "  ✓ Directory protected from move: $rel_dir"
      fi
    done

    # Phase 5: Mount individual files
    echo "Phase 5: Mounting protected files..."

    mount_count=0
    failed_count=0

    for dir in "''${!files_by_dir[@]}"; do
      # Mount each file in this directory
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

        # Mount file read-only
        if mount --bind "$resolved" "$dst" 2>/dev/null && \
           mount -o remount,ro,bind "$dst" 2>/dev/null; then
          # Make file immutable
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

    # Phase 6: Make fully protected directories read-only
    echo "Phase 6: Applying full protection to specified directories..."

    # Sort fully protected dirs by depth (deepest first to handle nested dirs)
    mapfile -t sorted_protected < <(
      for pdir in ${lib.concatStringsSep " " (map (d: "\"${d}\"") fullyProtectedDirs)}; do
        echo "$pdir"
      done | awk -F/ '{print NF-1, $0}' | sort -rn | cut -d' ' -f2-
    )

    for pdir in "''${sorted_protected[@]}"; do
      dir_path="${targetHome}/$pdir"

      if [ ! -d "$dir_path" ]; then
        echo "  ⚠ Directory doesn't exist: $pdir"
        continue
      fi

      # Check if it's already mounted
      if ! mountpoint -q "$dir_path" 2>/dev/null; then
        # If not mounted yet, bind mount it first
        mount --bind "$dir_path" "$dir_path" 2>/dev/null || {
          echo "  ⚠ Failed to bind mount: $pdir"
          continue
        }
      fi

      # Now remount as read-only
      if mount -o remount,ro,bind "$dir_path" 2>/dev/null; then
        echo "  ✓ Directory made read-only: $pdir"

        # Also make all files and subdirectories immutable for extra protection
        fd --hidden --no-ignore --type f --type d . "$dir_path" --exec-batch chattr +i {} 2>/dev/null \; || true
        chattr +i "$dir_path" 2>/dev/null || true
      else
        echo "  ⚠ Failed to make read-only: $pdir"
      fi
    done

    # Phase 7: Summary
    echo "Phase 7: Protection summary..."

    echo "  Directories protected from moving:"
    for dir in "''${!bind_mounted_dirs[@]}"; do
      echo "    • $dir"
    done | head -10

    echo "  Fully read-only directories:"
    for pdir in "''${sorted_protected[@]}"; do
      if mountpoint -q "${targetHome}/$pdir" 2>/dev/null && \
         mount | rg "${targetHome}/$pdir" | rg -q "ro,"; then
        echo "    • $pdir (verified read-only)"
      else
        echo "    • $pdir (WARNING: may not be read-only)"
      fi
    done

    echo "Protected mounts completed successfully"
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

    # Remove all immutable attributes
    fd --hidden --no-ignore --type f --type d . "${targetHome}" --exec-batch chattr -i {} 2>/dev/null \; || true
    chattr -i "${targetHome}" 2>/dev/null || true

    # Unmount all mounts in reverse order
    mount | rg -F "${targetHome}/" | awk '{print $3}' | tac | while read -r mp; do
      umount -l "$mp" 2>/dev/null || true
    done

    echo "Unmount completed"
  '';
in {
  environment.systemPackages = with pkgs; [
    fd
    util-linux
    e2fsprogs
    findutils
    gawk
    ripgrep
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
        TimeoutStartSec = "120s";
        Restart = "no";
      };

      restartTriggers = [
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
}
