# /modules/protected-mounts.nix
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

  protectedConfig = config.home-manager.users.${protectedUsername} or {};

  extractFilePaths = hm: let
    homeFiles = lib.mapAttrsToList (name: _: name) (hm.home.file or {});
    configFiles = lib.mapAttrsToList (name: _: ".config/${name}") (hm.xdg.configFile or {});
    dataFiles = lib.mapAttrsToList (name: _: ".local/share/${name}") (hm.xdg.dataFile or {});
  in
    homeFiles ++ configFiles ++ dataFiles;

  protectedRelativePaths = extractFilePaths protectedConfig;

  # Script to mount all protected paths
  mountScript = pkgs.writeShellScript "mount-protected" ''
    export PATH="${pkgs.util-linux}/bin:${pkgs.coreutils}/bin:$PATH"

    ${lib.concatStringsSep "\n" (map (relativePath: let
        sourcePath = "${protectedHome}/${relativePath}";
        targetPath = "${targetHome}/${relativePath}";
        upperDir = "${overlayBase}/upper/${relativePath}";
        workDir = "${overlayBase}/work/${relativePath}";
      in ''
        if [ -e "${sourcePath}" ]; then
          if [ -d "${sourcePath}" ]; then
            mkdir -p "${upperDir}" "${workDir}" "${targetPath}"
            mount -t overlay overlay \
              -o lowerdir="${sourcePath}",upperdir="${upperDir}",workdir="${workDir}" \
              "${targetPath}"
            chown -R ${username}:users "${upperDir}" "${workDir}" "${targetPath}"
          else
            mkdir -p "$(dirname "${targetPath}")"
            touch "${targetPath}"
            mount --bind "${sourcePath}" "${targetPath}"
            mount -o remount,ro,bind "${targetPath}"
          fi
        fi
      '')
      protectedRelativePaths)}
  '';

  # Script to unmount all protected paths
  unmountScript = pkgs.writeShellScript "unmount-protected" ''
    export PATH="${pkgs.util-linux}/bin:${pkgs.coreutils}/bin:$PATH"

    ${lib.concatMapStringsSep "\n" (relativePath: ''
        target="${targetHome}/${relativePath}"
        if mountpoint -q "$target" 2>/dev/null; then
          umount -l "$target" 2>/dev/null || true
        fi
      '')
      protectedRelativePaths}
  '';
in {
  systemd.tmpfiles.rules = [
    "d ${protectedHome} 0755 ${protectedUsername} protected-users -"
    "d ${overlayBase} 0755 root root -"
    "d ${overlayBase}/upper 0755 ${username} users -"
    "d ${overlayBase}/work 0755 ${username} users -"
  ];

  systemd.services = {
    # Service to unmount before regular user's home-manager
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

    # Service to mount after both home-managers complete
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

      unitConfig = {
        RequiresMountsFor = [protectedHome targetHome overlayBase];
      };

      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;

        ExecStartPre = pkgs.writeShellScript "wait-for-hm" ''
          timeout=30
          while [ ! -d "${protectedHome}/.config" ] && [ $timeout -gt 0 ]; do
            sleep 1
            timeout=$((timeout - 1))
          done
        '';

        ExecStart = mountScript;
        ExecStop = unmountScript;
      };
    };
  };
}
