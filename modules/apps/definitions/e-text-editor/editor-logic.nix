{
  pkgs,
  config,
  ...
}: let
  editorConstants = config.editorConstants;
  editorSettings = import ./editor-config.nix {inherit pkgs;};
  currentEditorExecutable = "${config.programs.nvf.finalPackage}/bin/nvim";
in {
  config = {
    programs.nvf = {
      enable = true;
      settings = editorSettings;
    };

    rawAppDefinitions."e-text-editor" = {
      type = "nix";
      id = editorConstants.packageName or "neovim";
      key = "e";
      appId = editorConstants.appIdForWM;
      isTerminalApp = true;
      launchCommand = "exec ${config.terminalConstants.bin} cli spawn -- ${currentEditorExecutable}";

      desktopFile = {
        generate = true;
        displayName = "Text Editor";
        iconName = editorConstants.iconName or "nvim";
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

    environment.variables = {
      EDITOR = currentEditorExecutable;
      VISUAL = currentEditorExecutable;
      SUDO_EDITOR = currentEditorExecutable;
    };
  };
}
