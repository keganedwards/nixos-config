# protected-mount.nix
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

  protectedConfig = config.home-manager.users.${protectedUsername} or {};

  blacklistPatterns = [
    ".config/environment.d/10-home-manager.conf"
    ".config/systemd/user/tray.target"
    ".config/fish/conf.d"
    ".local/state/home-manager"
    ".local/state/nix/profiles"
    ".nix-defexpr"
    ".nix-profile"
    ".manpath"
  ];

  isBlacklisted = path:
    lib.any (
      pattern:
        (path == pattern) || (lib.hasPrefix "${pattern}/" path)
    )
    blacklistPatterns;

  extractFilePaths = hm: let
    homeFiles = lib.mapAttrsToList (name: _: name) (hm.home.file or {});
    configFiles = lib.mapAttrsToList (name: _: ".config/${name}") (hm.xdg.configFile or {});
    dataFiles = lib.mapAttrsToList (name: _: ".local/share/${name}") (hm.xdg.dataFile or {});
  in
    lib.filter (path: !isBlacklisted path) (homeFiles ++ configFiles ++ dataFiles);

  allProtectedPaths = extractFilePaths protectedConfig;

  # Only get actual files, not directories
  getFilePaths = paths:
    lib.filter (path: let
      hasChildren =
        lib.any (
          otherPath:
            otherPath != path && lib.hasPrefix "${path}/" otherPath
        )
        paths;
    in
      !hasChildren)
    paths;

  filePaths = getFilePaths allProtectedPaths;

  # Get all parent directories that need protection
  getParentDirs = paths:
    lib.unique (
      lib.flatten (map (path: let
        parts = lib.splitString "/" path;
        makeParents = n:
          if n <= 0
          then []
          else [(lib.concatStringsSep "/" (lib.take n parts))] ++ (makeParents (n - 1));
      in
        makeParents (lib.length parts - 1))
      paths)
    );

  parentDirs = getParentDirs filePaths;

  mountScript = pkgs.writeShellScript "mount-protected" ''
    set -euo pipefail
    export PATH="${pkgs.util-linux}/bin:${pkgs.coreutils}/bin:${pkgs.e2fsprogs}/bin:${pkgs.findutils}/bin:$PATH"

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

    # Comprehensive function to clean a path of all protection
    clean_path() {
      local path="$1"

      # First try to remove immutable flag
      chattr -i "$path" 2>/dev/null || true

      # If it's a mount point, unmount it
      if mountpoint -q "$path" 2>/dev/null; then
        local max_attempts=5
        local attempt=0

        while mountpoint -q "$path" 2>/dev/null && [ $attempt -lt $max_attempts ]; do
          # Try normal unmount first
          umount "$path" 2>/dev/null || {
            # If that fails, try lazy unmount
            umount -l "$path" 2>/dev/null || true
          }
          attempt=$((attempt + 1))
          [ $attempt -lt $max_attempts ] && sleep 0.1
        done

        # Final attempt with force if still mounted
        if mountpoint -q "$path" 2>/dev/null; then
          umount -l "$path" 2>/dev/null || true
        fi
      fi

      # Remove immutable flag again in case unmounting revealed the underlying file
      chattr -i "$path" 2>/dev/null || true
    }

    # Clean up ALL existing mounts and immutable flags first
    echo "Cleaning up existing state..."

    # First pass: clean all parent directories (bottom-up to avoid conflicts)
    ${lib.concatMapStringsSep "\n" (dir: ''
      parent_path="${targetHome}/${dir}"
      if [ -e "$parent_path" ]; then
        clean_path "$parent_path"
      fi
    '') (lib.reverseList parentDirs)}

    # Second pass: clean all file paths
    ${lib.concatMapStringsSep "\n" (path: ''
      dst_path="${targetHome}/${path}"
      if [ -e "$dst_path" ]; then
        clean_path "$dst_path"
      fi
    '') (lib.reverseList filePaths)}

    # Third pass: ensure parent directories exist and have correct permissions
    echo "Setting up directory structure..."
    ${lib.concatMapStringsSep "\n" (dir: ''
        parent_path="${targetHome}/${dir}"

        # Create directory if it doesn't exist
        if [ ! -d "$parent_path" ]; then
          mkdir -p "$parent_path"
        fi

        # Ensure it's not mounted or immutable before changing ownership
        clean_path "$parent_path"

        # Set ownership and permissions
        chown ${username}:users "$parent_path" 2>/dev/null || {
          echo "  ⚠ Could not chown ${dir} (may be okay if parent is protected)" >&2
        }
        chmod 755 "$parent_path" 2>/dev/null || true
      '')
      parentDirs}

    # Mount all files with proper permissions
    echo "Mounting protected files..."
    ${lib.concatStringsSep "\n" (map (path: ''
        src_path="${protectedHome}/${path}"
        dst_path="${targetHome}/${path}"

        if [ -f "$src_path" ]; then
          # Ensure the destination is clean
          clean_path "$dst_path"

          # Create or recreate the destination file
          rm -f "$dst_path" 2>/dev/null || true
          touch "$dst_path"
          chown ${username}:users "$dst_path"
          chmod 644 "$dst_path"

          # Atomic mount and remount as read-only
          if mount --bind "$src_path" "$dst_path"; then
            if mount -o remount,ro,bind "$dst_path"; then
              # Make immutable after successful read-only mount
              chattr +i "$dst_path" 2>/dev/null || true
              echo "  ✓ ${path}"
            else
              echo "  ! Failed to remount read-only: ${path}" >&2
              umount "$dst_path" 2>/dev/null || true
            fi
          else
            echo "  ! Failed to mount: ${path}" >&2
          fi
        elif [ -d "$src_path" ]; then
          echo "  ⚠ Skipping directory: ${path}" >&2
        fi
      '')
      filePaths)}

    # Make parent directories immutable to prevent mv attacks
    # Only protect directories that actually contain mounted files
    echo "Protecting parent directories from mv attacks..."
    ${lib.concatMapStringsSep "\n" (dir: ''
        parent_path="${targetHome}/${dir}"
        if [ -d "$parent_path" ]; then
          # Check if this directory actually contains any mounted files
          has_mounts=false
          for file in "$parent_path"/*; do
            if [ -f "$file" ] && mountpoint -q "$file" 2>/dev/null; then
              has_mounts=true
              break
            fi
          done

          if [ "$has_mounts" = true ]; then
            chattr +i "$parent_path" 2>/dev/null && \
              echo "  ✓ Protected: ${dir}" || \
              echo "  ⚠ Could not protect: ${dir}" >&2
          fi
        fi
      '')
      parentDirs}

    echo "Protected mounts completed"
  '';

  unmountScript = pkgs.writeShellScript "unmount-protected" ''
    set -euo pipefail
    export PATH="${pkgs.util-linux}/bin:${pkgs.coreutils}/bin:${pkgs.e2fsprogs}/bin:$PATH"

    exec 200>"${lockFile}"
    if ! flock -w 10 -x 200; then
      echo "Failed to acquire lock" >&2
      exit 1
    fi

    trap 'flock -u 200' EXIT

    echo "Unmounting protected files..."

    # Comprehensive function to clean a path of all protection
    clean_path() {
      local path="$1"

      # First try to remove immutable flag
      chattr -i "$path" 2>/dev/null || true

      # If it's a mount point, unmount it
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

      # Remove immutable flag again
      chattr -i "$path" 2>/dev/null || true
    }

    # Remove immutable from all parent directories first
    ${lib.concatMapStringsSep "\n" (dir: ''
      parent_path="${targetHome}/${dir}"
      [ -e "$parent_path" ] && clean_path "$parent_path"
    '') (lib.reverseList parentDirs)}

    # Remove immutable and unmount files
    ${lib.concatMapStringsSep "\n" (path: ''
      dst_path="${targetHome}/${path}"
      [ -e "$dst_path" ] && clean_path "$dst_path"
    '') (lib.reverseList filePaths)}

    echo "Unmount completed"
  '';
in {
  systemd.tmpfiles.rules = [
    "d ${protectedHome} 0755 ${protectedUsername} protected-users -"
    "f ${lockFile} 0644 root root -"
  ];

  system.activationScripts."ensure-protected-mounts-${username}" = ''
    if ${pkgs.systemd}/bin/systemctl is-enabled --quiet protected-mount-${username}.service 2>/dev/null; then
      if ! ${pkgs.systemd}/bin/systemctl is-active --quiet protected-mount-${username}.service; then
        ${pkgs.systemd}/bin/systemctl start protected-mount-${username}.service || true
      fi
    fi
  '';

  systemd.services = {
    "protected-unmount-${username}" = {
      description = "Unmount protected files for ${username} before HM activation";
      before = ["home-manager-${username}.service"];
      wantedBy = ["home-manager-${username}.service"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        ExecStart = "${unmountScript}";
        TimeoutStartSec = "20s";
        KillMode = "mixed";
      };
    };

    "protected-mount-${username}" = {
      description = "Mount protected files for ${username}";
      wantedBy = ["multi-user.target"];
      after = [
        "home-manager-protect\\x2d${username}.service"
        "home-manager-${username}.service"
      ];
      requires = [
        "home-manager-${username}.service"
      ];

      unitConfig = {
        RequiresMountsFor = [protectedHome targetHome];
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStartPre = [
          "${unmountScript}"
          "${pkgs.coreutils}/bin/sleep 0.5"
        ];
        ExecStart = "${mountScript}";
        ExecStop = "${unmountScript}";
        TimeoutStartSec = "20s";
        TimeoutStopSec = "20s";
      };

      restartTriggers = [
        mountScript
        unmountScript
      ];
    };
  };
}
