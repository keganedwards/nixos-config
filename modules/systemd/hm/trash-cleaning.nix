{
  pkgs,
  config,
  ...
}: let
  downloadsPath = "${config.home.homeDirectory}/Downloads";
  screenshotsPath = "${config.home.homeDirectory}/Screenshots";
  cleanupAgeDays = 30;

  folderToTrashScript = pkgs.writeShellScript "folder-to-trash-script" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail

    echo "Checking '${downloadsPath}' for files older than ${toString cleanupAgeDays} days..."
    ${pkgs.fd}/bin/fd . "${downloadsPath}" --type f --changed-before "${toString cleanupAgeDays}d" -X ${pkgs.trash-cli}/bin/trash-put --

    echo "Checking '${screenshotsPath}' for files older than ${toString cleanupAgeDays} days..."
    ${pkgs.fd}/bin/fd . "${screenshotsPath}" --type f --changed-before "${toString cleanupAgeDays}d" -X ${pkgs.trash-cli}/bin/trash-put --

    echo "Folder to trash cleanup finished."
  '';
in {
  home.packages = [
    pkgs.fd
    pkgs.ripgrep
    pkgs.trash-cli
  ];

  systemd.user = {
    services."trash-cleanup" = {
      Unit = {
        Description = "Clean up Trash files older than ${toString cleanupAgeDays} days";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.trash-cli}/bin/trash-empty ${toString cleanupAgeDays}";
      };
    };

    timers."trash-cleanup" = {
      Unit = {
        Description = "Run Trash cleanup daily";
      };
      Timer = {
        OnCalendar = "daily";
        Persistent = true;
      };
      Install = {
        WantedBy = ["timers.target"];
      };
    };

    services."folder-to-trash-cleanup" = {
      Unit = {
        Description = "Move files older than ${toString cleanupAgeDays} days from Downloads and Screenshots to Trash";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${folderToTrashScript}";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    timers."folder-to-trash-cleanup" = {
      Unit = {
        Description = "Run Downloads/Screenshots to Trash cleanup daily";
      };
      Timer = {
        OnCalendar = "daily";
        Persistent = true;
      };
      Install = {
        WantedBy = ["timers.target"];
      };
    };
  };
}
