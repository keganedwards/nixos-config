{constants, ...}: {
  id = constants.videoPlayerAppId;
  key = "v";

  # No `type` is needed.

  launchCommand = let
    playerTitle = "video-player";
    playerArgs = "--title=${playerTitle} --player-operation-mode=pseudo-gui --save-position-on-quit --keep-open=yes";
  in "exec ${constants.videoPlayerBin} ${playerArgs} --idle=yes";

  appId = constants.videoPlayerAppId;

  desktopFile = {
    generate = true;
    displayName = "Video Player";
    desktopExecArgs = let
      title = "video-player";
    in "--title=${title} --player-operation-mode=pseudo-gui --save-position-on-quit --keep-open=yes";
    defaultAssociations = constants.videoMimeTypes or [];
    isDefaultHandler = true;
    categories = ["AudioVideo" "Video" "Player"];
  };
}
