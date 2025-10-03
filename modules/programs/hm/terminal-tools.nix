# /modules/programs/terminal-shell/security.nix (unchanged)
{
  pkgs,
  username,
  ...
}: let
  protectedUsername = "protect-${username}";
in {
  home-manager.users.${protectedUsername} = {
    programs = {
      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };

      nix-your-shell.enable = true;

      zoxide.enable = true;

      eza = {
        enable = true;
        git = true;
        icons = "always";
        colors = "auto";
      };

      fzf = {
        enable = true;
        enableFishIntegration = false;
      };

      fd = {
        enable = true;
        extraOptions = [
          "--hidden"
          "--follow"
        ];
        ignores = [
          ".git"
          "node_modules"
          ".steam"
          ".local/share/trash"
          ".local/share/steam"
        ];
      };

      bat = {
        enable = true;
        config = {
          style = "numbers";
          paging = "never";
        };
      };

      nix-index.enable = true;

      starship = {
        enable = true;
        enableTransience = true;
      };

      ripgrep = {
        enable = true;
        arguments = ["--smart-case" "--hidden" "--glob=!.git/*"];
      };

      pay-respects.enable = true;
    };
  };

  # Main user gets all the packages these programs provide
  home-manager.users.${username} = {
    home.packages = with pkgs; [
      xdg-utils
      tldr
      direnv
      nix-direnv
      zoxide
      eza
      fzf
      fd
      bat
      nix-index
      starship
      ripgrep
      pay-respects
    ];
  };
}
