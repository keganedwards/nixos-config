{username, ...}: {
  rawAppDefinitions."file-sync-manager" = {
    type = "pwa";
    id = "http://127.0.0.1:8384";
    key = "backspace";
  };

  home-manager.users.${username} = {
    services.syncthing = {
      enable = true;
      settings = {
        devices = {
          laptop = {
            id = "CKBYWSE-DNY4KVQ-U4AC42K-EGB2VPQ-NA33UFT-KRQPUJJ-VW5UQV7-YW7IQAP";
            autoAcceptFolders = true;
          };
          desktop = {
            id = "ZXRO7S4-RHWCI6E-C5R3MEV-5ALX4X2-QY2S4IQ-NZS6XUL-3GEES6U-NZALZQJ";
            autoAcceptFolders = true;
          };
          phone = {
            id = "QZIH32G-DFR6QMY-S2VXAND-CEYTCEE-DRH6KB4-W5TUDCB-H2YW44F-DW73GQT";
            autoAcceptFolders = true;
          };
        };
        folders = {
          notes = {
            path = "/home/${username}/Documents/notes";
            devices = ["laptop" "desktop" "phone"];
          };
          "important-documents" = {
            path = "/home/${username}/Documents/important-documents";
            devices = ["laptop" "desktop" "phone"];
          };
          pictures = {
            path = "/home/${username}/Pictures";
            devices = ["laptop" "desktop" "phone"];
          };
          "new-music" = {
            path = "/home/${username}/Music/new";
            devices = ["laptop" "desktop" "phone"];
          };
          "instrumental-music" = {
            path = "/home/${username}/Music/instrumental";
            devices = ["laptop" "desktop"];
          };
        };
      };
    };
  };
}
