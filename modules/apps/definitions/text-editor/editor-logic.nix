{username, ...}: {
  home-manager.users.${username} = {
    programs.neovide = {
      enable = true;
      settings.fork = true;
    };
  };

  rawAppDefinitions."e-text-editor" = {
    key = "e";
    id = "neovide";
    appId = "neovide";

    desktopFile = {
      generate = true;
      displayName = "Text Editor";
      iconName = "neovide";
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
