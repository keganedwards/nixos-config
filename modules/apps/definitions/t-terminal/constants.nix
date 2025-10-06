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
      
      # Launch command for regular terminal instances
      defaultLaunchCmd = "${pkgs.wezterm}/bin/wezterm start";
      
      # Launch command when you need a custom app ID
      launchWithAppId = appId: "${pkgs.wezterm}/bin/wezterm start --class ${appId}";
      
      # Whether this terminal supports custom app IDs
      supportsCustomAppId = true;
      
      # Default app ID for terminal windows (wezterm uses org.wezfurlong.wezterm by default)
      defaultAppId = "org.wezfurlong.wezterm";
    };
  };
}
