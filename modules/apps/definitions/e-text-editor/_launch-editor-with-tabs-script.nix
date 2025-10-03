{
  pkgs,
  editorCmd,
  editorTerminalSwayAppId,
  config,
  ...
}: let
  universalLauncher = import ../t-terminal/universal-multiplexer-launcher-script.nix {
    inherit config;
    inherit pkgs;
    appId = editorTerminalSwayAppId;
    commandToRun = editorCmd;
    appType = "editor";
  };
in
  pkgs.writeShellScriptBin "launch-editor-with-tabs" ''
    #!${pkgs.runtimeShell}

    # Handle sudoedit flag
    if [ "$1" = "--use-sudoedit" ]; then
      shift
      exec sudoedit "$@"
    fi

    # Pass all arguments to the universal launcher
    exec ${universalLauncher}/bin/universal-multiplexer-launcher-${editorTerminalSwayAppId} "$@"
  ''
