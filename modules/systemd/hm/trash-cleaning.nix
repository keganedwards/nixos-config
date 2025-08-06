# ./modules/home-manager/systemd/trash-cleaning.nix
# Requires pkgs.trash-cli to be installed via home.packages elsewhere
{
  pkgs,
  config,
  ...
}: let
  # Define paths relative to home directory
  downloadsPath = "${config.home.homeDirectory}/Downloads";
  screenshotsPath = "${config.home.homeDirectory}/Screenshots";
  # Define age in days for cleanup
  cleanupAgeDays = 30;
  # Calculate the mtime parameter for find (-mtime +N means N days or older when used like +N-1)
  findMtime = toString (cleanupAgeDays - 1);

  # --- Create the script using writeShellScript ---
  folderToTrashScript = pkgs.writeShellScript "folder-to-trash-script" ''
    #!${pkgs.bash}/bin/bash
    set -euo pipefail # Make script more robust

    echo "Checking '${downloadsPath}' for files older than ${toString cleanupAgeDays} days..."
    # Use -print0 and xargs -0 -r with trash-put for robustness with weird filenames
    # xargs comes from pkgs.findutils
    ${pkgs.findutils}/bin/find "${downloadsPath}" -mindepth 1 -type f -mtime +${findMtime} -print0 | ${pkgs.findutils}/bin/xargs -0 -r ${pkgs.trash-cli}/bin/trash-put --

    echo "Checking '${screenshotsPath}' for files older than ${toString cleanupAgeDays} days..."
    # xargs comes from pkgs.findutils
    ${pkgs.findutils}/bin/find "${screenshotsPath}" -mindepth 1 -type f -mtime +${findMtime} -print0 | ${pkgs.findutils}/bin/xargs -0 -r ${pkgs.trash-cli}/bin/trash-put --

    echo "Folder to trash cleanup finished."
  '';
  # --- End script definition ---
in {
  # 1. Systemd service and timer for emptying the actual trash can
  systemd.user.services."trash-cleanup" = {
    Unit = {
      Description = "Clean up Trash files older than ${toString cleanupAgeDays} days";
    };
    Service = {
      Type = "oneshot";
      # Requires 'trash-cli' package to be installed
      ExecStart = "${pkgs.trash-cli}/bin/trash-empty ${toString cleanupAgeDays}";
    };
  };

  systemd.user.timers."trash-cleanup" = {
    Unit = {
      Description = "Run Trash cleanup daily";
    };
    Timer = {
      OnCalendar = "daily";
      Persistent = true; # Run on next boot if missed
    };
    Install = {
      WantedBy = ["timers.target"];
    };
  };

  # 2. Systemd service and timer for moving old files from specific folders TO trash
  systemd.user.services."folder-to-trash-cleanup" = {
    Unit = {
      Description = "Move files older than ${toString cleanupAgeDays} days from Downloads and Screenshots to Trash";
    };
    Service = {
      Type = "oneshot";
      # Execute the script file generated above
      ExecStart = "${folderToTrashScript}";
      StandardOutput = "journal";
      StandardError = "journal";
    };
  };

  systemd.user.timers."folder-to-trash-cleanup" = {
    Unit = {
      Description = "Run Downloads/Screenshots to Trash cleanup daily";
    };
    Timer = {
      OnCalendar = "daily"; # Consider "daily 04:00:00" for a specific time
      Persistent = true;
    };
    Install = {
      WantedBy = ["timers.target"];
    };
  };
}
