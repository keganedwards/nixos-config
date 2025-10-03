{
  pkgs,
  username,
  ...
}: {
  config.rawAppDefinitions.image-viewer = {
    type = "nix";
    id = "swayimg";
    key = "i";
    launchCommand = "exec ${pkgs.swayimg}/bin/swayimg --class=swayimg";
    appId = "swayimg";
    desktopFile = {
      generate = true;
      displayName = "Image Viewer";
      iconName = "image-viewer";
      desktopExecArgs = "--class=swayimg";
      defaultAssociations = [
        "image/jpeg"
        "image/png"
        "image/gif"
        "image/webp"
        "image/bmp"
        "image/svg+xml"
        "image/tiff"
        "image/avif"
        "image/jxl"
        "image/x-icon"
        "image/vnd.djvu"
        "image/x-portable-pixmap"
        "image/x-portable-anymap"
        "image/x-portable-bitmap"
        "image/x-portable-graymap"
        "image/x-tga"
        "image/x-pcx"
        "image/x-xbm"
        "image/x-xpm"
        "image/x-cmu-raster"
        "image/x-photo-cd"
        "image/heif"
        "image/heic"
      ];
      isDefaultHandler = true;
      categories = ["Graphics" "Viewer"];
    };
  };
  config.home-manager.users.${username}.programs.swayimg.enable = true;
}
