{config, ...}: {
  config.rawAppDefinitions."music-player" = {
    id = config.mediaPlayerConstants.appId;
    key = "m";

    launchCommand = let
      playerTitle = "music-player";
      playerArgs = "--title=${playerTitle} --no-terminal --force-window=immediate --save-position-on-quit --audio-display=no --keep-open=yes --player-operation-mode=pseudo-gui --loop-playlist=inf";
    in "exec ${config.mediaPlayerConstants.bin} ${playerArgs} --idle=yes";

    appId = config.mediaPlayerConstants.appId;

    desktopFile = {
      generate = true;
      displayName = "Music Player";
      desktopExecArgs = let
        title = "music-player";
      in "--title=${title} --no-terminal --force-window=immediate --save-position-on-quit --audio-display=no --keep-open=yes --player-operation-mode=pseudo-gui --loop-playlist=inf";
      defaultAssociations = [
        "audio/mpeg"
        "audio/ogg"
        "audio/aac"
        "audio/flac"
        "audio/wav"
        "audio/x-ms-wma"
        "audio/opus"
        "audio/vorbis"
        "audio/x-matroska"
        "audio/mp4"
        "application/ogg"
        "audio/aacp"
        "audio/x-musepack"
        "audio/x-tta"
        "audio/x-aiff"
        "audio/x-ape"
        "audio/x-vorbis+ogg"
        "audio/x-flac+ogg"
        "audio/x-speex+ogg"
        "audio/x-scpls"
        "audio/x-mpegurl"
        "audio/vnd.rn-realaudio"
        "audio/x-realaudio"
        "audio/x-s3m"
        "audio/x-stm"
        "audio/x-it"
        "audio/x-xm"
        "audio/x-mod"
        "audio/midi"
      ];
      isDefaultHandler = true;
      categories = ["AudioVideo" "Audio" "Player"];
    };
  };
}
