{pkgs, ...}: {
  name = "wezterm";
  package = pkgs.wezterm;
  bin = "${pkgs.wezterm}/bin/wezterm";
  defaultLaunchCmd = "${pkgs.wezterm}/bin/wezterm start";
  launchWithAppId = appId: "${pkgs.wezterm}/bin/wezterm start --class ${appId}";
  supportsCustomAppId = true;
  defaultAppId = "org.wezfurlong.wezterm";
}
