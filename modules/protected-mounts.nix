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
  overlayBase = "/var/lib/overlay-${username}";
  lockFile = "/var/run/protected-mounts-${username}.lock";

  protectedConfig = config.home-manager.users.${protectedUsername} or {};

  extractFilePaths = hm: let
    homeFiles = lib.mapAttrsToList (name: _: name) (hm.home.file or {});
    configFiles = lib.mapAttrsToList (name: _: ".config/${name}") (hm.xdg.configFile or {});
    dataFiles = lib.mapAttrsToList (name: _: ".local/share/${name}") (hm.xdg.dataFile or {});
  in
    homeFiles ++ configFiles ++ dataFiles;

  protectedRelativePaths = extractFilePaths protectedConfig;

  parentDirs = lib.unique (map (
      path: let
        parts = lib.splitString "/" path;
      in
        if (lib.length parts) > 1
        then lib.concatStringsSep "/" (lib.init parts)
        else ""
    )
    protectedRelativePaths);

  mountScript = pkgs.writeShellScript "mount-protected" ''
    set -euo pipefail
    export PATH="${pkgs.util-linux}/bin:${pkgs.coreutils}/bin:${pkgs.e2fsprogs}/bin:$PATH"

    # Acquire lock
    exec 200>"${lockFile}"
    flock -x 200 || {
      echo "Failed to acquire lock" >&2
      exit 1
    }

    echo "Starting protected mounts for ${username}..."

    # First ensure everything is unmounted cleanly
    ${lib.concatMapStringsSep "\n" (relativePath: ''
        target="${targetHome}/${relativePath}"
        if mountpoint -q "$target" 2>/dev/null; then
          echo "Unmounting existing mount at $target..."
          umount -l "$target" 2>/dev/null || true
          sleep 0.5
        fi
      '')
      protectedRelativePaths}

    # Remove immutable attributes temporarily
    ${lib.concatStringsSep "\n" (map (
        parentDir:
          lib.optionalString (parentDir != "") ''
            if [ -d "${targetHome}/${parentDir}" ]; then
              chattr -i "${targetHome}/${parentDir}" 2>/dev/null || true
            fi
          ''
      )
      parentDirs)}

    # Mount all protected files
    ${lib.concatStringsSep "\n" (map (relativePath: let
        sourcePath = "${protectedHome}/${relativePath}";
        targetPath = "${targetHome}/${relativePath}";
        upperDir = "${overlayBase}/upper/${relativePath}";
        workDir = "${overlayBase}/work/${relativePath}";
      in ''
        if [ -e "${sourcePath}" ]; then
          echo "Processing ${relativePath}..."

          if [ -d "${sourcePath}" ]; then
            # Directory: use overlay
            mkdir -p "${upperDir}" "${workDir}" "${targetPath}"

            # Clean any stale overlay mounts
            rm -rf "${workDir}"/*

            if mount -t overlay overlay \
              -o lowerdir="${sourcePath}",upperdir="${upperDir}",workdir="${workDir}" \
              "${targetPath}"; then
              echo "✓ Mounted overlay for ${relativePath}"
              chown -R ${username}:users "${upperDir}" "${workDir}" "${targetPath}"
            else
              echo "✗ Failed to mount overlay for ${relativePath}" >&2
            fi
          else
            # File: use bind mount
            mkdir -p "$(dirname "${targetPath}")"

            # Remove any existing file
            rm -f "${targetPath}"
            touch "${targetPath}"

            if mount --bind "${sourcePath}" "${targetPath}"; then
              if mount -o remount,ro,bind "${targetPath}"; then
                echo "✓ Mounted readonly bind for ${relativePath}"
              else
                echo "✗ Failed to remount ${relativePath} as readonly" >&2
              fi
            else
              echo "✗ Failed to bind mount ${relativePath}" >&2
            fi
          fi
        else
          echo "⚠ Source ${sourcePath} does not exist, skipping" >&2
        fi
      '')
      protectedRelativePaths)}

    # Make parent directories immutable
    ${lib.concatStringsSep "\n" (map (
        parentDir:
          lib.optionalString (parentDir != "") ''
            if [ -d "${targetHome}/${parentDir}" ]; then
              if chattr +i "${targetHome}/${parentDir}" 2>/dev/null; then
                echo "✓ Made ${parentDir} immutable"
              else
                echo "⚠ Could not make ${parentDir} immutable" >&2
              fi
            fi
          ''
      )
      parentDirs)}

    echo "Protected mounts completed for ${username}"
    flock -u 200
  '';

  unmountScript = pkgs.writeShellScript "unmount-protected" ''
    set -euo pipefail
    export PATH="${pkgs.util-linux}/bin:${pkgs.coreutils}/bin:${pkgs.e2fsprogs}/bin:$PATH"

    # Acquire lock
    exec 200>"${lockFile}"
    flock -x 200 || {
      echo "Failed to acquire lock" >&2
      exit 1
    }

    echo "Unmounting protected files for ${username}..."

    # Remove immutable attributes
    ${lib.concatStringsSep "\n" (map (
        parentDir:
          lib.optionalString (parentDir != "") ''
            if [ -d "${targetHome}/${parentDir}" ]; then
              chattr -i "${targetHome}/${parentDir}" 2>/dev/null || true
            fi
          ''
      )
      parentDirs)}

    # Unmount in reverse order
    ${lib.concatMapStringsSep "\n" (relativePath: ''
        target="${targetHome}/${relativePath}"
        if mountpoint -q "$target" 2>/dev/null; then
          echo "Unmounting $target..."
          if umount -l "$target" 2>/dev/null; then
            echo "✓ Unmounted $target"
          else
            echo "⚠ Failed to cleanly unmount $target" >&2
          fi
        fi
      '')
      (lib.reverseList protectedRelativePaths)}

    echo "Unmount completed for ${username}"
    flock -u 200
  '';
  # Force remount script for systemd path unit
in {
  systemd = {
    tmpfiles.rules = [
      "d ${protectedHome} 0755 ${protectedUsername} protected-users -"
      "d ${overlayBase} 0755 root root -"
      "d ${overlayBase}/upper 0755 ${username} users -"
      "d ${overlayBase}/work 0755 ${username} users -"
      "f ${lockFile} 0644 root root -"
    ];

    services = {
      "protected-unmount-${username}" = {
        description = "Unmount protected files for ${username} before HM activation";
        before = ["home-manager-${username}.service"];
        requiredBy = ["home-manager-${username}.service"];

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
          "home-manager-${protectedUsername}.service"
          "home-manager-${username}.service"
        ];
        wants = [
          "home-manager-${protectedUsername}.service"
          "home-manager-${username}.service"
        ];
        requires = [
          "home-manager-${protectedUsername}.service"
        ];

        unitConfig = {
          RequiresMountsFor = [protectedHome targetHome overlayBase];
        };

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;

          ExecStartPre = [
            "${pkgs.coreutils}/bin/sleep 2"
            (pkgs.writeShellScript "wait-and-prepare" ''
              set -euo pipefail
              echo "Waiting for home-manager completion..."
              timeout=60
              while [ ! -d "${protectedHome}/.config" ] && [ $timeout -gt 0 ]; do
                sleep 2
                timeout=$((timeout - 2))
              done
              if [ ! -d "${protectedHome}/.config" ]; then
                echo "Timeout waiting for protected home-manager" >&2
                exit 1
              fi
              echo "Protected home ready, proceeding with mounts..."
            '')
          ];

          ExecStart = mountScript;
          ExecStop = unmountScript;
          ExecReload = "${pkgs.coreutils}/bin/true";
          Restart = "on-failure";
          RestartSec = "10s";
        };
      };
    };

    # Add a path unit to monitor for manual unmounting and auto-remount
    paths."protected-mount-monitor-${username}" = {
      description = "Monitor protected mounts for ${username}";
      wantedBy = ["multi-user.target"];
      pathConfig = {
        PathExists = "${targetHome}/.config/fish";
        PathChanged = "${targetHome}/.config/fish";
      };
    };
  };
  # Ensure mounts are refreshed on rebuild
  system.activationScripts."refresh-protected-mounts-${username}" = lib.stringAfter ["users"] ''
    echo "Refreshing protected mounts for ${username}..."
    ${pkgs.systemd}/bin/systemctl restart protected-mount-${username}.service || true
  '';
}
