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

  isContainer = path:
    lib.any (
      otherPath:
        (path != otherPath) && (lib.hasPrefix "${path}/" otherPath)
    )
    allProtectedPaths;

  leafPaths = lib.filter (path: !isContainer path) allProtectedPaths;

  # Get all parent directories that need protection (to prevent mv attacks)
  getParentDirs = paths:
    lib.unique (
      lib.flatten (map (path: let
        parts = lib.splitString "/" path;
        # Create list of all parent paths
        makeParents = n:
          if n <= 0
          then []
          else [(lib.concatStringsSep "/" (lib.take n parts))] ++ (makeParents (n - 1));
      in
        makeParents (lib.length parts - 1))
      paths)
    );

  parentDirs = getParentDirs allProtectedPaths;

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

    safe_unmount() {
      local mount_point="$1"
      local max_attempts=3
      local attempt=0

      while mountpoint -q "$mount_point" 2>/dev/null && [ $attempt -lt $max_attempts ]; do
        umount "$mount_point" 2>/dev/null || umount -l "$mount_point" 2>/dev/null || true
        attempt=$((attempt + 1))
        [ $attempt -lt $max_attempts ] && sleep 0.1
      done

      if mountpoint -q "$mount_point" 2>/dev/null; then
        umount -l "$mount_point" 2>/dev/null || true
      fi
    }

    # Clean up ALL existing mounts and immutable flags first
    echo "Cleaning up existing state..."

    # Remove immutable from conf.d
    chattr -i "${targetHome}/.config/fish/conf.d" 2>/dev/null || true
    safe_unmount "${targetHome}/.config/fish/conf.d"

    # Remove immutable from all protected paths and unmount
    ${lib.concatMapStringsSep "\n" (path: ''
      dst_path="${targetHome}/${path}"
      if [ -e "$dst_path" ]; then
        chattr -i "$dst_path" 2>/dev/null || true
        safe_unmount "$dst_path"
      fi
    '') (lib.reverseList leafPaths)}

    # Remove immutable from all parent directories that we protected
    ${lib.concatMapStringsSep "\n" (dir: ''
      parent_path="${targetHome}/${dir}"
      if [ -d "$parent_path" ]; then
        chattr -i "$parent_path" 2>/dev/null || true
      fi
    '') (lib.reverseList parentDirs)}

    # Ensure parent directories exist with correct permissions
    echo "Setting up directory structure..."
    ${lib.concatMapStringsSep "\n" (dir: ''
        parent_path="${targetHome}/${dir}"
        if [ ! -d "$parent_path" ]; then
          mkdir -p "$parent_path"
        fi
        chown ${username}:users "$parent_path"
        chmod 755 "$parent_path"
      '')
      parentDirs}

    # Mount conf.d (only hardcoded special case)
    if [ -d "${protectedHome}/.config/fish/conf.d" ]; then
      echo "Setting up protected conf.d..."
      mkdir -p "${targetHome}/.config/fish/conf.d"
      chown ${username}:users "${targetHome}/.config/fish/conf.d"
      chmod 755 "${targetHome}/.config/fish/conf.d"

      if mount --bind "${protectedHome}/.config/fish/conf.d" "${targetHome}/.config/fish/conf.d"; then
        if mount -o remount,ro,bind "${targetHome}/.config/fish/conf.d"; then
          chattr +i "${targetHome}/.config/fish/conf.d" 2>/dev/null || true
          echo "  ✓ conf.d mounted"
        fi
      fi
    fi

    # Mount all leaf paths with proper permissions
    echo "Mounting protected files..."
    ${lib.concatStringsSep "\n" (map (path: ''
        src_path="${protectedHome}/${path}"
        dst_path="${targetHome}/${path}"

        if [ -e "$src_path" ]; then
          if [ -d "$src_path" ]; then
            # Directory
            if [ ! -d "$dst_path" ]; then
              mkdir -p "$dst_path"
            fi
            chown ${username}:users "$dst_path"
            chmod 755 "$dst_path"

            if mount --bind "$src_path" "$dst_path"; then
              if mount -o remount,ro,bind "$dst_path"; then
                chattr +i "$dst_path" 2>/dev/null || true
                echo "  ✓ ${path}"
              else
                echo "  ! Failed remount: ${path}" >&2
                umount "$dst_path" 2>/dev/null || true
              fi
            fi
          elif [ -f "$src_path" ]; then
            # File - create with proper permissions
            rm -f "$dst_path" 2>/dev/null || true
            touch "$dst_path"
            chown ${username}:users "$dst_path"
            chmod 644 "$dst_path"

            if mount --bind "$src_path" "$dst_path"; then
              if mount -o remount,ro,bind "$dst_path"; then
                chattr +i "$dst_path" 2>/dev/null || true
                echo "  ✓ ${path}"
              else
                echo "  ! Failed remount: ${path}" >&2
                umount "$dst_path" 2>/dev/null || true
              fi
            fi
          fi
        fi
      '')
      leafPaths)}

    # Make parent directories immutable to prevent mv attacks
    # But only the ones that contain protected files
    echo "Protecting parent directories from mv attacks..."
    ${lib.concatMapStringsSep "\n" (dir: ''
        parent_path="${targetHome}/${dir}"
        if [ -d "$parent_path" ]; then
          # Check if this directory actually contains any mounted files
          has_mounts=false
          ${lib.concatMapStringsSep "\n" (path: ''
            if [[ "${path}" == ${dir}/* ]] && mountpoint -q "${targetHome}/${path}" 2>/dev/null; then
              has_mounts=true
            fi
          '')
          leafPaths}

          # Also check for conf.d
          if [[ ".config/fish" == "${dir}" ]] && mountpoint -q "${targetHome}/.config/fish/conf.d" 2>/dev/null; then
            has_mounts=true
          fi

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

    safe_unmount() {
      local mount_point="$1"
      chattr -i "$mount_point" 2>/dev/null || true

      local max_attempts=3
      local attempt=0
      while mountpoint -q "$mount_point" 2>/dev/null && [ $attempt -lt $max_attempts ]; do
        umount "$mount_point" 2>/dev/null || umount -l "$mount_point" 2>/dev/null || true
        attempt=$((attempt + 1))
        [ $attempt -lt $max_attempts ] && sleep 0.1
      done

      if mountpoint -q "$mount_point" 2>/dev/null; then
        umount -l "$mount_point" 2>/dev/null || true
      fi
    }

    # Remove immutable and unmount conf.d
    safe_unmount "${targetHome}/.config/fish/conf.d"

    # Remove immutable from all parent directories first
    ${lib.concatMapStringsSep "\n" (dir: ''
      chattr -i "${targetHome}/${dir}" 2>/dev/null || true
    '') (lib.reverseList parentDirs)}

    # Remove immutable and unmount leaf paths
    ${lib.concatMapStringsSep "\n" (path: ''
      dst_path="${targetHome}/${path}"
      [ -e "$dst_path" ] && safe_unmount "$dst_path"
    '') (lib.reverseList leafPaths)}

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
        ExecStart = unmountScript;
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
          unmountScript
          "${pkgs.coreutils}/bin/sleep 0.5"
        ];
        ExecStart = mountScript;
        ExecStop = unmountScript;
        TimeoutStartSec = "20s";
        TimeoutStopSec = "20s";
        Restart = "on-failure";
        RestartSec = "2s";
      };

      restartTriggers = [
        mountScript
        unmountScript
      ];
    };
  };
}
