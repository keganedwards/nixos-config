{
  pkgs,
  lib,
  username,
  lockscreenConstants,
  windowManagerConstants,
  faillock,
  ...
}: let
  lockscreenCmd = pkgs.writeShellScriptBin "lockscreen" ''
    exec ${pkgs.${lockscreenConstants.name}}/bin/${lockscreenConstants.name}
  '';
in {
  environment.systemPackages = [
    lockscreenCmd
    pkgs.${lockscreenConstants.name}
  ];

  home-manager.users.${username} = {
    catppuccin.${lockscreenConstants.name}.enable = lib.mkForce false;

    programs.${lockscreenConstants.name} = {
      enable = true;
      settings = {
        general.hide_cursor = true;

        background = [
          {
            monitor = "";
            path = "$HOME/.local/share/wallpapers/Bing/lockscreen.jpg";
          }
        ];

        input-field = [
          {
            monitor = "";
            size = "200, 50";
            outline_thickness = 3;
            outer_color = "rgb(151515)";
            inner_color = "rgb(200, 200, 200)";
            font_color = "rgb(10, 10, 10)";
            placeholder_text = "<i>Input Password...</i>";
            hide_input = false;
            fail_color = "rgb(204, 34, 34)";
            fail_text = "<i>$FAIL</i>";
            position = "0, -20";
            halign = "center";
            valign = "center";
          }
        ];

        label = [
          {
            monitor = "";
            text = ''cmd[update:1000] cat ${faillock.messageFile} 2>/dev/null || echo ""'';
            color = "rgba(200, 200, 200, 1.0)";
            font_size = 16;
            font_family = "Noto Sans";
            position = "0, 80";
            halign = "center";
            valign = "center";
          }
          {
            monitor = "";
            text = "$TIME";
            color = "rgba(200, 200, 200, 1.0)";
            font_size = 55;
            font_family = "Noto Sans";
            position = "0, 180";
            halign = "center";
            valign = "center";
          }
        ];
      };
    };
  };

  imports = [
    (windowManagerConstants.setKeybinding "Mod+Shift+X" "lockscreen")
  ];
}
