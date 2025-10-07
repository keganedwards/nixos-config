{pkgs, ...}: {
  package = pkgs.mpv;
  name = "mpv";
  bin = "${pkgs.mpv}/bin/mpv";
  appId = "mpv";
}
