# /constants/default.nix
{
  pkgs,
  lib,
  username,
}: let
  windowManager = import ./window-manager.nix {inherit pkgs lib;} username;
in {
  inherit windowManager;
  terminal = import ./terminal.nix {inherit pkgs windowManager;};
  terminalShell = import ./terminal-shell.nix {inherit pkgs;};
  editor = import ./editor.nix;
  mediaPlayer = import ./media-player.nix {inherit pkgs;};
  browser = import ./browser.nix {inherit pkgs;};
  lockscreen = import ./lock-screen.nix {inherit pkgs;};
  loginManager = import ./login-manager.nix {inherit pkgs;};
}
