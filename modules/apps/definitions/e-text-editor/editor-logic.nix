{
  pkgs,
  config,
  constants,
  ...
}: let
  editorSettings = import ./editor-config.nix {inherit pkgs;};

  # Get the configured neovim package from programs.nvf
  # This will be available after nvf builds it
  currentEditorExecutable = "${config.programs.nvf.finalPackage}/bin/nvim";

  customEditorLauncherScript = import ./_launch-editor-with-tabs-script.nix {
    inherit pkgs;
    multiplexerSessionName = "main-editor-session";
    editorCmd = currentEditorExecutable;
    terminalCmd = constants.terminalBin;
    editorTerminalSwayAppId = constants.editorAppIdForSway;
    multiplexerBin = "${pkgs.tmux}/bin/tmux";
  };

  smartLauncherScriptPkg = import ./_smart-editor-launcher-script.nix {
    inherit pkgs;
    defaultEditorLaunchCmd = "${customEditorLauncherScript}/bin/launch-editor-with-tabs";
  };

  smartLauncherExePath = "${smartLauncherScriptPkg}/bin/smart-editor-launcher";
in {
  # Enable and configure nvf
  programs.nvf = {
    enable = true;
    settings = editorSettings;
  };

  e-text-editor = {
    type = "nix";
    id = constants.editorNixPackageName or "neovim";
    key = "e";

    launchCommand = "exec ${smartLauncherExePath}";
    appId = constants.editorAppIdForSway;
    isTerminalApp = true;
    desktopFile = {
      generate = true;
      displayName = "Default Editor (Tabbed)";
      iconName = constants.editorIconName or "nvim";
      defaultAssociations = constants.commonTextEditorMimeTypes;
      isDefaultHandler = true;
      categories = ["Utility" "TextEditor" "Development"];
    };
  };

  environment.systemPackages = [
    pkgs.tmux
    pkgs.coreutils
    pkgs.jq
    customEditorLauncherScript
    smartLauncherScriptPkg
  ];

  environment.variables = {
    EDITOR = smartLauncherExePath;
    VISUAL = smartLauncherExePath;
    SUDO_EDITOR = currentEditorExecutable;
  };
}
