{username, ...}: {
  programs.lazygit.enable = true;

  home-manager.users.${username} = {
    programs.lazygit.enable = true;
  };

  rawAppDefinitions."n-lazygit" = {
    key = "n";
    id = "lazygit";
    isTerminalApp = true;
  };
}
