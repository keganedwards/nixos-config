{constants, ...}: {
  "music-player" = {
    id = constants.videoPlayerAppId;
    key = "m";

    launchCommand = let
      playerTitle = "music-player";
      playerArgs = "--title=${playerTitle} --no-terminal --force-window=immediate --save-position-on-quit --audio-display=no --keep-open=yes --player-operation-mode=pseudo-gui --loop-playlist=inf";
    in "exec ${constants.videoPlayerBin} ${playerArgs} --idle=yes";

    appId = constants.videoPlayerAppId;

    desktopFile = {
      generate = true;
      displayName = "Music Player";
      desktopExecArgs = let
        title = "music-player";
      in "--title=${title} --no-terminal --force-window=immediate --save-position-on-quit --audio-display=no --keep-open=yes --player-operation-mode=pseudo-gui --loop-playlist=inf";
      defaultAssociations = constants.audioMimeTypes or [];
      isDefaultHandler = true;
      categories = ["AudioVideo" "Audio" "Player"];
    };
  };
}
