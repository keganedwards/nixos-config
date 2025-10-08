{pkgs, ...}: {
  name = "fish";
  package = pkgs.fish;
  bin = "${pkgs.fish}/bin/fish";

  # How to reload the shell configuration
  reloadCommand = "${pkgs.fish}/bin/fish -c 'source ~/.config/fish/config.fish'";

  # Config file location
  configFile = "~/.config/fish/config.fish";
}
