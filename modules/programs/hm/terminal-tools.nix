{pkgs, ...}: {
  home.packages = with pkgs; [
    xdg-utils
    tldr
    tmux
  ];

  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };

    nix-your-shell = {
      enable = true;
    };

    zoxide = {
      enable = true;
    };

    eza = {
      enable = true;
      git = true;
      icons = "always";
    };

    # Enable FZF but disable Fish integration since we use custom functions
    fzf = {
      enable = true;
      tmux.enableShellIntegration = true;
      enableFishIntegration = false;
    };

    fd = {
      enable = true;
      extraOptions = [
        "--hidden"
        "--follow"
        "--exclude"
        ".git"
        "--exclude"
        "node_modules"
        "--exclude"
        ".steam"
        "--exclude"
        ".local/share/trash"
      ];
    };

    bat = {
      enable = true;
      config = {
        style = "numbers";
        paging = "never";
      };
    };

    nix-index = {
      enable = true;
    };

    starship = {
      enable = true;
      enableTransience = true;
    };

    ripgrep = {
      enable = true;
      arguments = ["--smart-case" "--hidden" "--glob=!.git/*"];
    };

    pay-respects = {
      enable = true;
    };
  };
}
