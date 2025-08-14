# File: modules/home-manager/apps/definitions/t-terminal/default.nix
{
  pkgs,
  constants,
  ...
}: let
  # Import the terminal configuration logic
  terminalPrograms = import ./terminal-programs.nix {inherit constants;};

  # Import the terminal app definition
  terminalApp = import ./terminal-app.nix {inherit pkgs constants;};
in
  # Merge the terminal configuration with the terminal app
  terminalPrograms
  // {
    terminal-app = terminalApp;
  }
