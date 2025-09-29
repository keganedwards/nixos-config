{
  pkgs,
  constants,
  username,
  ...
}: let
  terminalPrograms = import ./terminal-programs.nix {inherit username constants;};
  terminalApp = import ./terminal-app.nix {inherit pkgs constants;};
in
  terminalPrograms // terminalApp
