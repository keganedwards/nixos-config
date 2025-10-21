{
  pkgs,
  username,
  ...
}: let
  terminalLauncher = import ../t-terminal/terminal-launcher.nix {inherit pkgs;};
in {
  home-manager.users.${username} = {
    programs.neovide = {
      enable = true;
      settings.fork = true;
    };
  };

  environment.systemPackages = [
    pkgs.neovim-remote
    terminalLauncher
  ];

  rawAppDefinitions."e-text-editor" = {
    key = "e";
    id = "neovide";
    appId = "neovide";

    launchCommand = "${terminalLauncher}/bin/terminal-launcher --editor";

    desktopFile = {
      generate = true;
      displayName = "Text Editor";
      iconName = "neovide";
      desktopExecArgs = "${terminalLauncher}/bin/terminal-launcher --editor %F"; # Add this line
      defaultAssociations = [
        "text/plain"
        "text/markdown"
        "application/json"
        "application/toml"
        "application/x-yaml"
        "text/x-shellscript"
        "text/x-python"
        "application/javascript"
        "text/javascript"
        "text/x-nix"
      ];
      isDefaultHandler = true;
      categories = ["Utility" "TextEditor" "Development"];
    };
  };
}
