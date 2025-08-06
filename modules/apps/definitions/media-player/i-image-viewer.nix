# This file no longer has a top-level key.
# Its key will be generated from its filename: "media-player-i-image-viewer".
{constants, ...}: {
  id = constants.videoPlayerAppId;
  key = "i";

  # No `type` is needed. It will correctly default to "externally-managed".

  launchCommand = let
    viewerTitle = "image-viewer";
    viewerArgs = "--title=${viewerTitle} --image-display-duration=inf --player-operation-mode=pseudo-gui --no-audio --keep-open=yes";
  in "exec ${constants.videoPlayerBin} ${viewerArgs}";

  appId = constants.videoPlayerAppId;

  desktopFile = {
    generate = true;
    displayName = "Image Viewer";
    desktopExecArgs = let
      title = "image-viewer";
    in "--title=${title} --image-display-duration=inf --player-operation-mode=pseudo-gui --no-audio --keep-open=yes";
    defaultAssociations = constants.imageMimeTypes or [];
    isDefaultHandler = true;
    categories = ["Graphics" "Viewer"];
  };
}
