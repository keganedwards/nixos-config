# File: modules/home-manager/apps/definitions/e-text-editor/editor-logic.nix
{
  pkgs,
  constants,
  inputs,
  ...
}: let
  # --- Component Definitions ---
  editorConfigData = import ./editor-config.nix {inherit pkgs inputs;};
  currentEditorPackage = editorConfigData.customNvfNeovimDerivation.neovim;
  currentEditorExecutable = "${currentEditorPackage}/bin/nvim";

  # --- CORRECTED SECTION ---
  # 1. Import your custom script instead of the generic one.
  customEditorLauncherScript = import ./_launch-editor-with-tabs-script.nix {
    inherit pkgs;
    # Provide the arguments your script expects:
    multiplexerSessionName = "main-editor-session";
    editorCmd = currentEditorExecutable;
    terminalCmd = constants.terminalBin;
    editorTerminalSwayAppId = constants.editorAppIdForSway;
    multiplexerBin = "${pkgs.tmux}/bin/tmux";
  };

  # 2. Build the smart entrypoint script that handles sudoedit.
  #    This now points to the correct launcher.
  smartLauncherScriptPkg = import ./_smart-editor-launcher-script.nix {
    inherit pkgs;
    # Point it to the binary created by your custom script.
    defaultEditorLaunchCmd = "${customEditorLauncherScript}/bin/launch-editor-with-tabs";
  };
  smartLauncherExePath = "${smartLauncherScriptPkg}/bin/smart-editor-launcher";
in {
  type = "nix";
  id = constants.editorNixPackageName or "neovim";
  key = "e";

  launchCommand = "exec ${smartLauncherExePath}";

  appId = constants.editorAppIdForSway;
  isTerminalApp = true;

  appDefHomePackages = [
    currentEditorPackage
    pkgs.tmux
    pkgs.coreutils
    pkgs.jq
    # 3. Ensure the correct package is added to your profile.
    customEditorLauncherScript # <-- This now installs `launch-editor-with-tabs`
    smartLauncherScriptPkg
  ];

  desktopFile = {
    generate = true;
    displayName = "Default Editor (Tabbed)";
    iconName = constants.editorIconName or "nvim";
    defaultAssociations = constants.commonTextEditorMimeTypes;
    isDefaultHandler = true;
    categories = ["Utility" "TextEditor" "Development"];
  };

  home.sessionVariables = {
    # Your EDITOR is the smart launcher, which correctly chains to `launch-editor-with-tabs`
    EDITOR = smartLauncherExePath;
    VISUAL = smartLauncherExePath;
    SUDO_EDITOR = currentEditorExecutable; # This is correct for sudoedit
  };
}
