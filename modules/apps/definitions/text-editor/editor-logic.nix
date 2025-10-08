{
  config,
  editorConstants,
  terminalConstants,
  ...
}: let
  currentEditorExecutable = "${config.programs.nvf.finalPackage}/bin/nvim";
in {
  config = {
    rawAppDefinitions."e-text-editor" = {
      key = "5";
      type = "nix";
      id = editorConstants.packageName;
      isTerminalApp = true;
      launchCommand = "exec ${terminalConstants.bin} cli spawn -- ${currentEditorExecutable}";

      desktopFile = {
        generate = true;
        displayName = "Text Editor";
        inherit (editorConstants) iconName;
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
