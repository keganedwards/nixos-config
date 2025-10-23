{
  pkgs,
  username,
  ...
}: let
  downloadsPath = "/home/${username}/Downloads";
  screenshotsPath = "/home/${username}/Screenshots";
  cleanupAgeDays = 30;

  folderToTrashScript = pkgs.writeShellScript "folder-to-trash-script" ''
    #!${pkgs.bash}/bin/bash  # Corrected from pkgs/bash to pkgs.bash
    set -euo pipefail

    echo "Checking '${downloadsPath}' for files older than ${toString cleanupAgeDays} days..."
    ${pkgs.fd}/bin/fd . "${downloadsPath}" --type f --changed-before "${toString cleanupAgeDays}d" -X ${pkgs.trash-cli}/bin/trash-put --

    echo "Checking '${screenshotsPath}' for files older than ${toString cleanupAgeDays} days..."
    ${pkgs.fd}/bin/fd . "${screenshotsPath}" --type f --changed-before "${toString cleanupAgeDays}d" -X ${pkgs.trash-cli}/bin/trash-put --

    echo "Folder to trash cleanup finished."
  '';
in {
  environment.systemPackages = [
    pkgs.fd
    pkgs.trash-cli
  ];

  systemd.user = {
    services."trash-cleanup" = {
      unitConfig = {
        Description = "Clean up Trash files older than ${toString cleanupAgeDays} days";
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.trash-cli}/bin/trash-empty ${toString cleanupAgeDays}";
      };
    };

    timers."trash-cleanup" = {
      unitConfig = {
        Description = "Run Trash cleanup daily";
      };
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
      wantedBy = ["timers.target"];
    };

    services."folder-to-trash-cleanup" = {
      unitConfig = {
        Description = "Move files older than ${toString cleanupAgeDays} days from Downloads and Screenshots to Trash";
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${folderToTrashScript}";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    timers."folder-to-trash-cleanup" = {
      unitConfig = {
        Description = "Run Downloads/Screenshots to Trash cleanup daily";
      };
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
      wantedBy = ["timers.target"];
    };
  };
}
