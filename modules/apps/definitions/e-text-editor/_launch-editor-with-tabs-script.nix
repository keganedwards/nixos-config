# modules/home-manager/apps/definitions/e-text-editor/_launch-editor-with-tabs-script.nix
{
  pkgs,
  multiplexerSessionName,
  editorCmd,
  terminalCmd,
  editorTerminalSwayAppId,
  ...
}: let
  universalLauncher = import ../t-terminal/universal-tmux-launcher-script.nix {
    inherit pkgs;
    appId = editorTerminalSwayAppId;
    sessionName = multiplexerSessionName;
    terminalBin = terminalCmd;
    commandToRun = editorCmd;
    appType = "editor"; # Specify this is an editor
  };
in
  pkgs.writeShellScriptBin "launch-editor-with-tabs" ''
    #!${pkgs.runtimeShell}

    # Pass all arguments to the universal launcher
    exec ${universalLauncher}/bin/universal-tmux-launcher-${editorTerminalSwayAppId} "$@"
  ''
