{
  config,
  pkgs,
  username,
  ...
}: let
  dotfilesRoot = "/home/${username}/.dotfiles";
in {
  home-manager.users.${username} = {
    programs.mpv = {
      enable = true;
      package = pkgs.mpv-unwrapped.wrapper {
        scripts = with pkgs.mpvScripts; [
          mpris
          mpv-playlistmanager
          eisa01.smartskip
          eisa01.smart-copy-paste-2
        ];
        mpv = pkgs.mpv-unwrapped.override {
          waylandSupport = true;
        };
      };
      config = {
        vo = "gpu";
        hwdec = "auto-safe";
        save-position-on-quit = true;
      };
      profiles = {};
    };

    home.file = {
      ".config/mpv/scripts" = {
        source = config.home-manager.users.${username}.lib.file.mkOutOfStoreSymlink "${dotfilesRoot}/.config/mpv/scripts";
      };

      ".config/mpv/script-opts" = {
        source = config.home-manager.users.${username}.lib.file.mkOutOfStoreSymlink "${dotfilesRoot}/.config/mpv/script-opts";
      };
    };
  };
}
