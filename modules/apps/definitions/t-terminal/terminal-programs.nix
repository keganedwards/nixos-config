# File: modules/home-manager/apps/definitions/t-terminal/terminal-programs.nix
{...}: {
  programs.foot = {
    enable = true;
    settings = {
      main = {
        dpi-aware = "yes";
      };
      mouse = {
        hide-when-typing = "yes";
      };
    };
  };
}
