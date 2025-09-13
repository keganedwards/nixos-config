# modules/home-manager/apps/definitions/media-player-i-image-viewer/default.nix
{
  pkgs,
  constants,
  ...
}: {
  type = "nix";
  id = "swayimg";
  key = "i";

  launchCommand = "exec ${pkgs.swayimg}/bin/swayimg --class=swayimg";

  appId = "swayimg";

  appDefHomePackages = [pkgs.swayimg];

  desktopFile = {
    generate = true;
    displayName = "Image Viewer";
    iconName = "image-viewer";
    desktopExecArgs = "--class=swayimg";
    defaultAssociations = constants.imageMimeTypes or [];
    isDefaultHandler = true;
    categories = ["Graphics" "Viewer"];
  };
}
