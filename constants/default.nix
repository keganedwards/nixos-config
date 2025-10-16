{
  pkgs,
  lib,
  username,
}: {
  windowManager = import ./window-manager.nix {inherit pkgs lib;} username;
  terminal = import ./terminal.nix {inherit pkgs;};
  terminalShell = import ./terminal-shell.nix {inherit pkgs;};
  editor = import ./editor.nix;
  mediaPlayer = import ./media-player.nix {inherit pkgs;};
  browser = import ./browser.nix;
  lockscreen = import ./lock-screen.nix {inherit pkgs;};
  loginManager = import ./login-manager.nix {inherit pkgs;};
}
