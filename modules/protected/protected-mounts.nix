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
      echo "This may be a fresh system - skipping protected mounts" >&2
      exit 0
    fi

    GENERATION_PATH=$(readlink -f "$HM_GENERATION")
    echo "Using generation: $GENERATION_PATH"

    if [ ! -d "$GENERATION_PATH/home-files" ]; then
      echo "No home-files directory found in generation" >&2
      echo "Skipping protected mounts" >&2
      exit 0
    fi

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

    # Function to wait for unmounts to complete by polling
    wait_for_unmounts() {
      local max_attempts=10
      local attempt=0

      while ((attempt < max_attempts)); do
        if ! mount | rg -F "${targetHome}/" >/dev/null 2>&1; then
          return 0  # No mounts left, we're done
        fi

        # Wait a bit before checking again
        sleep 0.1
        attempt=$((attempt + 1))
      done

      # Force any remaining unmounts
      mount | rg -F "${targetHome}/" | awk '{print $3}' | tac | while read -r mp; do
        umount -lf "$mp" 2>/dev/null || true
      done

      return 0
    }

    # Phase 1: Clean existing state
    echo "Phase 1: Cleaning existing state..."

    # Use parallel processing for cleaning immutable attributes (faster)
    if [ -d "${targetHome}" ]; then
      {
        fd --hidden --no-ignore --type f --type d . "${targetHome}" -d 5 --exec-batch chattr -i {} 2>/dev/null \; || true
        chattr -i "${targetHome}" 2>/dev/null || true
      } &
      clean_pid=$!

      # Start unmounting in parallel with the cleaning
      if mount | rg -F "${targetHome}/" >/dev/null 2>&1; then
        mount | rg -F "${targetHome}/" | awk '{print $3}' | tac | while read -r mp; do
          umount -l "$mp" 2>/dev/null || true
        done
      fi

      wait $clean_pid

      # Poll until all unmounts are complete
      wait_for_unmounts
    fi

    echo "  ✓ Clean slate"

    # Phase 2: Discover and categorize files
    echo "Phase 2: Discovering files..."

    declare -A files_by_dir=()
    declare -A all_dirs=()
    declare -A dir_mount_counts=()
    declare -A fully_protected_map=()

    cd "$GENERATION_PATH/home-files"

    # Pre-populate fully protected directories map for faster lookups
    for pdir in ${lib.concatStringsSep " " (map (d: "\"${d}\"") fullyProtectedDirs)}; do
      fully_protected_map["$pdir"]=1
    done

    # Use fd for faster file discovery
    while IFS= read -r file; do
      rel_path="''${file#./}"

      # Skip excluded files
      is_excluded "$rel_path" && continue

      # Skip files in fully protected directories
      if is_in_fully_protected "$rel_path"; then
        continue
      fi

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
    done < <(fd --type f --type l --hidden --no-ignore . . 2>/dev/null)

    total_files=0
    for dir in "''${!dir_mount_counts[@]}"; do
      total_files=$((total_files + ''${dir_mount_counts["$dir"]}))
    done

    echo "  ✓ Found $total_files files across ''${#files_by_dir[@]} directories"

    # Phase 3: Create directory structure
    echo "Phase 3: Creating directory structure..."

    # Use mkdir with parent creation to optimize
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
      if mount --bind "$dir_path" "$dir_path" 2>/dev/null; then
        bind_mounted_dirs["$rel_dir"]=1
      fi
    done

    echo "  ✓ Protected ''${#bind_mounted_dirs[@]} directories from moving"

    # Phase 5: Mount individual files
    echo "Phase 5: Mounting protected files..."

    # Create temp directory for status tracking
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT

    mount_count=0
    failed_count=0
    total_count=0

    process_file() {
      local rel_path="$1"
      local tmpdir="$2"
      local src="$GENERATION_PATH/home-files/$rel_path"
      local dst="${targetHome}/$rel_path"

      # Resolve source
      if [ -L "$src" ]; then
        local resolved=$(readlink -f "$src" 2>/dev/null || echo "$src")
      else
        local resolved="$src"
      fi

      [ -f "$resolved" ] || { echo "fail" > "$tmpdir/$$"; return; }

      # Remove existing file
      if [ -e "$dst" ]; then
        chattr -i "$dst" 2>/dev/null || true
        rm -f "$dst" 2>/dev/null || true
      fi

      # Create mount point
      touch "$dst" 2>/dev/null || {
        echo "  ⚠ Cannot create: $dst" >&2
        echo "fail" > "$tmpdir/$$"
        return
      }

      chown ${username}:users "$dst"
      chmod 644 "$dst"

      # Mount file read-only
      if mount --bind "$resolved" "$dst" 2>/dev/null && \
         mount -o remount,ro,bind "$dst" 2>/dev/null; then
        # Make file immutable
        chattr +i "$dst" 2>/dev/null || true
        echo "success" > "$tmpdir/$$"
      else
        echo "  ⚠ Failed to mount: $dst" >&2
        rm -f "$dst" 2>/dev/null || true
        echo "fail" > "$tmpdir/$$"
      fi
    }

    export -f process_file
    export GENERATION_PATH targetHome username tmpdir

    # Process files with controlled parallelism
    for dir in "''${!files_by_dir[@]}"; do
      while IFS= read -r rel_path; do
        [ -z "$rel_path" ] && continue

        # Wait for any completed background jobs to limit parallelism
        while [ $(jobs -r | wc -l) -ge 10 ]; do
          sleep 0.01
        done

        process_file "$rel_path" "$tmpdir" &
        total_count=$((total_count + 1))
      done <<< "''${files_by_dir[$dir]}"
    done

    # Wait for all background jobs to complete
    wait

    # Count results
    mount_count=$(find "$tmpdir" -type f -exec grep -l "success" {} \; 2>/dev/null | wc -l)
    failed_count=$(find "$tmpdir" -type f -exec grep -l "fail" {} \; 2>/dev/null | wc -l)

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
        fd --hidden --no-ignore --type f --type d . "$dst_dir" --exec-batch chattr -i {} 2>/dev/null \; || true
        chattr -i "$dst_dir" 2>/dev/null || true

        # Unmount if mounted
        if mountpoint -q "$dst_dir" 2>/dev/null; then
          umount -l "$dst_dir" 2>/dev/null || true

          # Wait for unmount to complete
          for i in {1..10}; do
            if ! mountpoint -q "$dst_dir" 2>/dev/null; then
              break
            fi
            sleep 0.1
          done

          # Force unmount if still mounted
          if mountpoint -q "$dst_dir" 2>/dev/null; then
            umount -lf "$dst_dir" 2>/dev/null || true
          fi
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
          # Count files for stats
          file_count=$(fd --type f --hidden --no-ignore . "$dst_dir" 2>/dev/null | wc -l)
          echo "  ✓ Directory mounted read-only: $pdir ($file_count files)"

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
        if mount | rg -F "$dst_dir" | rg -q "ro,"; then
          file_count=$(fd --type f --hidden --no-ignore . "$dst_dir" 2>/dev/null | wc -l)
          if [[ "$file_count" -gt 0 ]]; then
            echo "  ✓ $pdir is read-only and accessible ($file_count files)"
          else
            echo "  ⚠ $pdir is mounted but may not have any readable files"
          fi
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
    export PATH="${pkgs.util-linux}/bin:${pkgs.coreutils}/bin:${pkgs.e2fsprogs}/bin:${pkgs.fd}/bin:${pkgs.findutils}/bin:${pkgs.gawk}/bin:${pkgs.ripgrep}/bin:$PATH"

    exec 200>"${lockFile}"
    if ! flock -w 10 -x 200; then
      echo "Failed to acquire lock" >&2
      exit 1
    fi
    trap 'flock -u 200' EXIT

    echo "Unmounting protected files..."

    # Remove all immutable attributes with fd
    fd --hidden --no-ignore --type f --type d . "${targetHome}" -d 5 --exec-batch chattr -i {} 2>/dev/null \; || true
    chattr -i "${targetHome}" 2>/dev/null || true

    # Unmount all mounts (reverse order)
    mount | rg -F "${targetHome}/" | awk '{print $3}' | tac | while read -r mp; do
      umount -l "$mp" 2>/dev/null || true
    done

    # Wait for unmounts to complete
    max_attempts=10
    attempt=0

    while ((attempt < max_attempts)); do
      if ! mount | rg -F "${targetHome}/" >/dev/null 2>&1; then
        break  # No mounts left, we're done
      fi

      # Wait a bit before checking again
      sleep 0.1
      attempt=$((attempt + 1))
    done

    # Force any remaining unmounts
    if mount | rg -F "${targetHome}/" >/dev/null 2>&1; then
      echo "Forcing remaining unmounts..."
      mount | rg -F "${targetHome}/" | awk '{print $3}' | tac | while read -r mp; do
        umount -lf "$mp" 2>/dev/null || true
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
    ripgrep
  ];

  systemd.tmpfiles.rules = [
    "d ${protectedHome} 0755 ${protectedUsername} users -"
    "f ${lockFile} 0644 root root -"
  ];

  systemd.services = {
    "protected-mount-${username}" = {
      description = "Mount protected files for ${username}";
      wantedBy = ["multi-user.target"];

      after = [
        "local-fs.target"
        "home-manager-${protectedUsername}.service"
        "home-manager-${username}.service"
      ];

      wants = [
        "home-manager-${protectedUsername}.service"
        "home-manager-${username}.service"
      ];

      # Make these optional - don't fail if they don't exist
      unitConfig = {
        RequiresMountsFor = [protectedHome targetHome];
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${mountScript}";
        ExecReload = "${mountScript}";
        TimeoutStartSec = "180s";
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
