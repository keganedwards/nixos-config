{
  lib,
  config,
  ...
}: let
  # List of standard XDG user directories to symlink
  folders = [
    "Documents"
    "Downloads"
    "Music"
    "Pictures"
    "Public"
    # "Share" is not a standard XDG dir, keep if you use it customly
    "Share"
    "Templates"
    "Videos"
    # Note: "Desktop" is also a standard XDG dir, add if needed
    # "Desktop"
  ];

  # Base path on your external drive
  externalBase = "/mnt/external";

  # Create attribute set for home.file, mapping folder names to symlink configs
  folderLinks = lib.genAttrs folders (folder: {
    # Creates a symlink in the home directory pointing outside the Nix store
    source = config.lib.file.mkOutOfStoreSymlink "${externalBase}/${folder}";
    # Optional: Force creation/replacement if the target exists as a directory
    # force = true;
  });
  # --- trashLink variable removed ---
  # trashLink = {
  #   ".local/share/Trash" = {
  #     source = config.lib.file.mkOutOfStoreSymlink "${externalBase}/Trash";
  #   };
  # };
in {
  # Apply only the folder links to home.file
  # The // trashLink part is removed
  home.file = folderLinks;

  # Ensure the target directories exist on the external drive (optional but good practice)
  # This uses systemd-tmpfiles rules, managed by Home Manager
  home.activation.createExternalUserDirs = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Create directories on the external drive if they don't exist
    # Ensure ${externalBase} is mounted before home-manager activation runs!
    ${lib.concatMapStringsSep "\n" (folder: ''
        $DRY_RUN_CMD mkdir -p "${externalBase}/${folder}"
      '')
      folders}
    # We no longer manage the external Trash directory here
    # $DRY_RUN_CMD mkdir -p "${externalBase}/Trash"
  '';
}
