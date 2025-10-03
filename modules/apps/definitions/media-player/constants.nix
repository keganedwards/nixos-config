{
  lib,
  pkgs,
  ...
}: {
  options.mediaPlayerConstants = lib.mkOption {
    type = lib.types.attrs;
    default = {
      package = pkgs.mpv;
      name = "mpv";
      bin = "${pkgs.mpv}/bin/mpv";
      appId = "mpv";
    };
  };
}
