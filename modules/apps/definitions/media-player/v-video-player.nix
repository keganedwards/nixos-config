{config, ...}: {
  config.rawAppDefinitions."video-player" = {
    id = config.mediaPlayerConstants.appId;
    key = "v";
    launchCommand = let
      playerTitle = "video-player";
      playerArgs = "--title=${playerTitle} --player-operation-mode=pseudo-gui --save-position-on-quit --keep-open=yes";
    in "exec ${config.mediaPlayerConstants.bin} ${playerArgs} --idle=yes";

    appId = config.mediaPlayerConstants.appId;

    desktopFile = {
      generate = true;
      displayName = "Video Player";
      desktopExecArgs = let
        title = "video-player";
      in "--title=${title} --player-operation-mode=pseudo-gui --save-position-on-quit --keep-open=yes";
      defaultAssociations = [
        "video/mpeg"
        "video/mp4"
        "video/quicktime"
        "video/x-msvideo"
        "video/x-matroska"
        "video/webm"
        "video/ogg"
        "video/x-flv"
        "video/x-ms-wmv"
        "application/vnd.rn-realmedia"
        "application/vnd.apple.mpegurl"
        "application/dash+xml"
        "video/x-m4v"
        "video/3gpp"
        "video/x-theora+ogg"
        "video/x-ogm+ogg"
        "video/x-flc"
        "video/x-fli"
        "video/x-nuv"
        "video/vnd.vivo"
        "video/wavelet"
        "video/x-anim"
        "video/x-nsv"
        "video/x-real-video"
        "video/x-sgi-movie"
        "video/x-motion-jpeg"
        "video/x-dv"
        "video/x-cdg"
      ];
      isDefaultHandler = true;
      categories = ["AudioVideo" "Video" "Player"];
    };
  };
}
