{windowManagerConstants, ...}: let
  wm = windowManagerConstants;
in {
  imports = [
    (wm.setActionKeybindings {
      "Mod+Shift+S" = {screenshot = {};};
    })
    (wm.setSettings {
      screenshot-path = "~/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";
    })
  ];
}
