{
  config,
  pkgs,
  username,
  ...
}: let
  wmConstants = config.windowManagerConstants;

  wmExitWithBraveKill = pkgs.writeShellScript "wm-exit-brave" ''
    ${pkgs.flatpak}/bin/flatpak kill com.brave.Browser 2>/dev/null || true

    for i in {1..20}; do
      if ! ${pkgs.flatpak}/bin/flatpak ps --columns=application 2>/dev/null | ${pkgs.ripgrep}/bin/rg -q "com.brave.Browser"; then
        break
      fi
      sleep 0.1
    done

    ${wmConstants.exit}
  '';
in {
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "wm-exit-safe" ''
      exec ${wmExitWithBraveKill}
    '')
  ];

  home-manager.users.${username} = wmConstants.setKeybinding "Alt+Shift+Escape" "${wmExitWithBraveKill}";

  home-manager.users.${username}.home.packages = [
    (pkgs.writeShellScriptBin "wm-exit-safe" ''
      exec ${wmExitWithBraveKill}
    '')
  ];
}
