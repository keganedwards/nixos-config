{
  username,
  terminalConstants,
  ...
}: {
  imports = [
    ./config.nix
  ];

  home-manager.users.${username} = {
    programs.neovide = terminalConstants.programConfig;
  };

  environment.systemPackages =
    [
      terminalConstants.terminalLauncher
    ]
    ++ terminalConstants.supportPackages;

  rawAppDefinitions."e-text-editor" = {
    key = "e";
    appId = terminalConstants.appIds.editor;
    type = "externally-managed";
    launchCommand = "${terminalConstants.terminalLauncher}/bin/terminal-launcher --editor --desktop e";

    desktopFile = {
      generate = true;
      displayName = "Text Editor";
      inherit (terminalConstants) iconName;
      desktopExecArgs = "${terminalConstants.terminalLauncher}/bin/terminal-launcher --editor --desktop e %F";
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
