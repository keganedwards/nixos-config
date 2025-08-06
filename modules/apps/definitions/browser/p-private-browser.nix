# This file is now purely declarative data.
{constants, ...}: {
  type = "flatpak";
  # The ID of the Flatpak package to run.
  id = constants.defaultWebbrowserFlatpakId;
  key = "p";

  # We declaratively state the extra arguments to be added to the launch command.
  # The helper will handle building the full command string.
  commandArgs = "--tor";
}
