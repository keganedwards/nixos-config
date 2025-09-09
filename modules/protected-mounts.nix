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
    ".config/environment.d/ssh-askpass.conf"
    ".config/systemd/user/tray.target"
    ".config/fish/conf.d" # We'll handle this specially
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

  topLevelDirs = lib.unique (map (
      path: let
        parts = lib.splitString "/" path;
      in
        lib.head parts
    )
    leafPaths);

  protectedServiceName = "home-manager-protect\\x2d${username}.service";

  mountScript = pkgs.writeShellScript "mount-protected" ''
    set -euo pipefail
    export PATH="${pkgs.util-linux}/bin:${pkgs.coreutils}/bin:${pkgs.e2fsprogs}/bin:${pkgs.findutils}/bin:$PATH"

    exec 200>"${lockFile}"
    flock -x 200 || {
      echo "Failed to acquire lock" >&2
      exit 1
    }

    echo "Starting protected mounts for ${username}..."

    if [ ! -d "${protectedHome}" ]; then
      echo "Protected home does not exist yet" >&2
      flock -u 200
      exit 1
    fi

    # First unmount existing mounts and remove immutable flags
    ${lib.concatMapStringsSep "\n" (path: ''
      dst_path="${targetHome}/${path}"
      if [ -e "$dst_path" ]; then
        chattr -i "$dst_path" 2>/dev/null || true
        while mountpoint -q "$dst_path" 2>/dev/null; do
          umount -f "$dst_path" 2>/dev/null || umount -l "$dst_path" 2>/dev/null || true
          sleep 0.1
        done
      fi
    '') (lib.reverseList leafPaths)}

    # Handle conf.d specially - unmount and remove immutable
    if [ -e "${targetHome}/.config/fish/conf.d" ]; then
      chattr -i "${targetHome}/.config/fish/conf.d" 2>/dev/null || true
      while mountpoint -q "${targetHome}/.config/fish/conf.d" 2>/dev/null; do
        umount -f "${targetHome}/.config/fish/conf.d" 2>/dev/null || umount -l "${targetHome}/.config/fish/conf.d" 2>/dev/null || true
        sleep 0.1
      done
    fi

    # Remove immutable from top-level dirs
    ${lib.concatStringsSep "\n" (map (dir: ''
        chattr -i "${targetHome}/${dir}" 2>/dev/null || true
      '')
      topLevelDirs)}

    # Ensure directory structure with correct ownership
    echo "Setting up directory structure..."
    for leaf_path in ${lib.concatStringsSep " " (map (p: "'${p}'") leafPaths)}; do
      parent_dir="$(dirname "${targetHome}/$leaf_path")"
      while [ "$parent_dir" != "${targetHome}" ] && [ "$parent_dir" != "/" ]; do
        if [ ! -d "$parent_dir" ]; then
          mkdir -p "$parent_dir"
        fi
        chown ${username}:users "$parent_dir"
        chmod 755 "$parent_dir"
        parent_dir="$(dirname "$parent_dir")"
      done
    done

    # Create and protect conf.d directory
    echo "Setting up protected conf.d..."
    if [ -d "${protectedHome}/.config/fish/conf.d" ]; then
      # Ensure parent exists
      mkdir -p "${targetHome}/.config/fish"
      chown ${username}:users "${targetHome}/.config/fish"

      # Create or ensure conf.d exists
      mkdir -p "${targetHome}/.config/fish/conf.d"
      chown ${username}:users "${targetHome}/.config/fish/conf.d"

      # Mount it read-only
      if mount --bind "${protectedHome}/.config/fish/conf.d" "${targetHome}/.config/fish/conf.d"; then
        if mount -o remount,ro,bind "${targetHome}/.config/fish/conf.d"; then
          echo "  ✓ Mounted read-only: .config/fish/conf.d"
          # Make it immutable
          chattr +i "${targetHome}/.config/fish/conf.d" 2>/dev/null && \
            echo "  ✓ Made immutable: .config/fish/conf.d" || \
            echo "  ⚠ Could not make immutable: .config/fish/conf.d" >&2
        else
          echo "  ✗ Failed to remount conf.d readonly" >&2
          umount "${targetHome}/.config/fish/conf.d" 2>/dev/null || true
        fi
      else
        echo "  ✗ Failed to mount conf.d" >&2
      fi
    fi

    # Mount other leaf paths
    ${lib.concatStringsSep "\n" (map (path: ''
        src_path="${protectedHome}/${path}"
        dst_path="${targetHome}/${path}"

        if [ -e "$src_path" ]; then
          echo "Processing: ${path}"

          if [ -d "$src_path" ]; then
            # Directory - mount read-only
            if [ ! -d "$dst_path" ]; then
              mkdir -p "$dst_path"
              chown ${username}:users "$dst_path"
            fi

            if mount --bind "$src_path" "$dst_path"; then
              if mount -o remount,ro,bind "$dst_path"; then
                echo "  ✓ Mounted read-only: ${path}"
                chattr +i "$dst_path" 2>/dev/null || \
                  echo "  ⚠ Could not make immutable: ${path}" >&2
              else
                echo "  ✗ Failed to remount readonly: ${path}" >&2
                umount "$dst_path" 2>/dev/null || true
              fi
            else
              echo "  ✗ Failed to mount: ${path}" >&2
            fi
          elif [ -f "$src_path" ]; then
            # File - mount read-only
            rm -f "$dst_path" 2>/dev/null || true
            touch "$dst_path"
            chown ${username}:users "$dst_path"

            if mount --bind "$src_path" "$dst_path"; then
              if mount -o remount,ro,bind "$dst_path"; then
                echo "  ✓ Mounted read-only file: ${path}"
                chattr +i "$dst_path" 2>/dev/null || true
              else
                echo "  ✗ Failed to remount readonly: ${path}" >&2
                umount "$dst_path" 2>/dev/null || true
              fi
            else
              echo "  ✗ Failed to mount file: ${path}" >&2
            fi
          fi
        else
          echo "  ⚠ Source does not exist: ${path}" >&2
        fi
      '')
      leafPaths)}

    # Make only top-level directories immutable
    echo ""
    echo "Protecting top-level directories..."
    ${lib.concatStringsSep "\n" (map (dir: ''
        top_dir="${targetHome}/${dir}"
        if [ -d "$top_dir" ]; then
          if chattr +i "$top_dir" 2>/dev/null; then
            echo "  ✓ Made immutable: ${dir}"
          else
            echo "  ⚠ Could not make immutable: ${dir}" >&2
          fi
        fi
      '')
      topLevelDirs)}

    echo ""
    echo "Protected mounts completed"
    flock -u 200
  '';

  unmountScript = pkgs.writeShellScript "unmount-protected" ''
    set -euo pipefail
    export PATH="${pkgs.util-linux}/bin:${pkgs.coreutils}/bin:${pkgs.e2fsprogs}/bin:$PATH"

    exec 200>"${lockFile}"
    flock -x 200 || {
      echo "Failed to acquire lock" >&2
      exit 1
    }

    echo "Unmounting protected files..."

    # Remove immutable from conf.d
    chattr -i "${targetHome}/.config/fish/conf.d" 2>/dev/null || true
    while mountpoint -q "${targetHome}/.config/fish/conf.d" 2>/dev/null; do
      echo "  Unmounting conf.d..."
      umount -f "${targetHome}/.config/fish/conf.d" 2>/dev/null || umount -l "${targetHome}/.config/fish/conf.d" 2>/dev/null || true
      sleep 0.1
    done

    # Remove immutable from top-level dirs
    ${lib.concatStringsSep "\n" (map (dir: ''
      chattr -i "${targetHome}/${dir}" 2>/dev/null || true
    '') (lib.reverseList topLevelDirs))}

    # Remove immutable and unmount leaf paths
    ${lib.concatMapStringsSep "\n" (path: ''
      dst_path="${targetHome}/${path}"
      if [ -e "$dst_path" ]; then
        chattr -i "$dst_path" 2>/dev/null || true
        while mountpoint -q "$dst_path" 2>/dev/null; do
          echo "  Unmounting $dst_path..."
          umount -f "$dst_path" 2>/dev/null || umount -l "$dst_path" 2>/dev/null || true
          sleep 0.1
        done
      fi
    '') (lib.reverseList leafPaths)}

    echo "Unmount completed"
    flock -u 200
  '';
in {
  systemd.tmpfiles.rules = [
    "d ${protectedHome} 0755 ${protectedUsername} protected-users -"
    "f ${lockFile} 0644 root root -"
  ];

  systemd.services = {
    "protected-unmount-${username}" = {
      description = "Unmount protected files for ${username} before HM activation";
      before = ["home-manager-${username}.service"];
      wantedBy = ["home-manager-${username}.service"];

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = false;
        ExecStart = unmountScript;
      };
    };

    "protected-mount-${username}" = {
      description = "Mount protected files for ${username}";
      wantedBy = ["multi-user.target"];
      after = [
        protectedServiceName
        "home-manager-${username}.service"
      ];
      wants = [
        protectedServiceName
      ];

      unitConfig = {
        RequiresMountsFor = [protectedHome targetHome];
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        ExecStartPre = [
          unmountScript
          "${pkgs.coreutils}/bin/sleep 1"
        ];

        ExecStart = mountScript;
        ExecStop = unmountScript;

        Restart = "no";
      };
    };
  };
}
