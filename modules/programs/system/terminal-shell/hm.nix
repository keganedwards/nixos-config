# /modules/system/terminal-shell/hm.nix
{
  config,
  lib,
  pkgs,
  ...
}: let
  absDotfilesRoot = "${config.home.homeDirectory}/.dotfiles";
  fishFilePaths = [
    "fish/conf.d/keybindings.fish"
    "fish/conf.d/00-startup.fish"
    "fish/conf.d/99-tmux.fish"
    "fish/conf.d/aliases.fish"
    "fish/conf.d/fzf_bindings.fish"
    "fish/conf.d/fzf_options.fish"
    "fish/functions/fish_prompt.fish"
    "fish/functions/fo.fish"
    "fish/functions/haskellEnv.fish"
    "fish/functions/mkcd.fish"
    "fish/functions/op.fish"
    "fish/functions/pythonEnv.fish"
    "fish/functions/fzf_print_dir.fish"
  ];
  fishSymlinks = lib.listToAttrs (map (filePath: {
      name = "${config.home.homeDirectory}/.config/${filePath}";
      value = {source = config.lib.file.mkOutOfStoreSymlink "${absDotfilesRoot}/config/${filePath}";};
    })
    fishFilePaths);
in {
  home.packages = with pkgs; [
    xdg-utils
    tldr
  ];
  programs.fish = {
    enable = true;
  };
  programs.nix-your-shell = {
    enable = true;
    enableFishIntegration = true;
  };
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };
  programs.eza = {
    enable = true;
    enableFishIntegration = true;
    git = true;
    icons = "always";
  };
  programs.fzf = {
    enable = true;
    tmux.enableShellIntegration = true;
    enableFishIntegration = false;
  };
  programs.fd = {
    enable = true;
    extraOptions = ["--hidden" "--follow" "--exclude" ".git" "--exclude" "node_modules"];
  };
  programs.bat = {
    enable = true;
    config = {
      style = "numbers";
      paging = "never";
    };
  };
  programs.nix-index = {
    enable = true;
    enableFishIntegration = true;
  };
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    enableTransience = true;
  };
  programs.ripgrep = {
    enable = true;
    arguments = ["--smart-case" "--hidden" "--glob=!.git/*"];
  };
  programs.pay-respects = {
    enable = true;
  };
  home.file = fishSymlinks;
}
