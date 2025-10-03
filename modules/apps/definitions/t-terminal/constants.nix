{
  lib,
  pkgs,
  ...
}: {
  options.terminalConstants = lib.mkOption {
    type = lib.types.attrs;
    default = {
      name = "wezterm";
      package = pkgs.wezterm;
      bin = "${pkgs.wezterm}/bin/wezterm";
      launchCmd = "${pkgs.wezterm}/bin/wezterm start --class";
    };
  };
}
