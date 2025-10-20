{
  config,
  lib,
  pkgs,
  windowManagerConstants,
  browserConstants,
  ...
}: let
  wmConstants = windowManagerConstants;
  browser = browserConstants;
  processedApps = config.applications or {};

  # Helper to make workspace names unambiguous (prefix numeric ones)
  makeWorkspaceName = name:
    if name != null && builtins.match "^[0-9]+$" name != null
    then "ws-${name}" # Prefix numeric names with "ws-" to avoid index confusion
    else name;

  allWorkspaceNames = lib.unique (lib.filter (name: name != null)
    (lib.mapAttrsToList (
        _: appConfig:
          makeWorkspaceName (appConfig.workspaceName or appConfig.key or null)
      )
      processedApps));
  sortedWorkspaceNames = lib.sort (a: b: a < b) allWorkspaceNames;

  mkWorkspaceScript = workspaceName: appConfig: let
    launchCmd = appConfig.launchCommand or null;
    isBlankWorkspace = launchCmd == null;

    scriptContent =
      if isBlankWorkspace
      then ''
        #!${pkgs.runtimeShell}
        # Focus the workspace by name
        ${pkgs.niri}/bin/niri msg action focus-workspace "${workspaceName}"
      ''
      else ''
        #!${pkgs.runtimeShell}
        set -e

        # Focus the workspace by name
        ${pkgs.niri}/bin/niri msg action focus-workspace "${workspaceName}"

        # Force launch mode
        if [ "$FORCE_LAUNCH" = "1" ]; then
          ${launchCmd}
          exit 0
        fi

        # Check if the current (now focused) workspace has any windows
        current_workspace_info=$(${pkgs.niri}/bin/niri msg --json workspaces | \
          ${pkgs.jq}/bin/jq -r '.[] | select(.is_focused == true)')

        has_window=$(echo "$current_workspace_info" | ${pkgs.jq}/bin/jq -r '.active_window_id // "null"')

        if [ "$has_window" = "null" ]; then
          ${launchCmd}
        fi
      '';
  in
    pkgs.writeScriptBin "goto-workspace-${lib.strings.sanitizeDerivationName workspaceName}" scriptContent;

  mkBrowserWorkspaceScript = workspaceName:
    pkgs.writeScriptBin "browser-to-${lib.strings.sanitizeDerivationName workspaceName}" ''
      #!${pkgs.runtimeShell}
      set -e

      # Focus the workspace by name
      ${pkgs.niri}/bin/niri msg action focus-workspace "${workspaceName}"

      # Check if the current (now focused) workspace has any windows
      current_workspace_info=$(${pkgs.niri}/bin/niri msg --json workspaces | \
        ${pkgs.jq}/bin/jq -r '.[] | select(.is_focused == true)')

      has_window=$(echo "$current_workspace_info" | ${pkgs.jq}/bin/jq -r '.active_window_id // "null"')

      if [ "$has_window" = "null" ]; then
        ${browser.launchCommand} &
      fi
    '';

  generatedWMConfigsPerApp =
    lib.mapAttrsToList (
      _appKeyFromConfig: appConfig: let
        bindingKey = appConfig.key or null;
        # Apply the prefix transformation here
        workspaceName = makeWorkspaceName (appConfig.workspaceName or bindingKey);
        appIdCriteria = appConfig.appId or null;
        launchCmd = appConfig.launchCommand or null;
        ignoreWindowAssignment = appConfig.ignoreWindowAssignment or false;

        isBlankWorkspace = launchCmd == null;

        workspaceScript =
          if bindingKey != null && workspaceName != null
          then mkWorkspaceScript workspaceName appConfig
          else null;

        keybindingsForThisApp =
          if workspaceScript != null && bindingKey != null
          then {
            "ISO_Level5_Shift+${bindingKey}".action.spawn = ["${workspaceScript}/bin/${workspaceScript.name}"];
            "ISO_Level5_Shift+Alt+${bindingKey}".action.spawn = ["sh" "-c" "FORCE_LAUNCH=1 ${workspaceScript}/bin/${workspaceScript.name}"];
            "ISO_Level5_Shift+Shift+${bindingKey}".action.move-window-to-workspace = workspaceName;
          }
          else {};

        windowRulesForThisApp =
          if !isBlankWorkspace && !ignoreWindowAssignment && appIdCriteria != null && workspaceName != null && appConfig.type != "web-page"
          then let
            appIdList =
              if lib.isList appIdCriteria
              then appIdCriteria
              else [appIdCriteria];
          in
            lib.flatten (lib.map (idString: [
                {
                  matches = [{app-id = "^${lib.escapeRegex idString}$";}];
                  open-on-workspace = workspaceName;
                }
              ])
              appIdList)
          else [];

        scriptsForThisApp =
          if workspaceScript != null
          then [workspaceScript]
          else [];

        workspaceNameForAllocation =
          if workspaceName != null
          then workspaceName
          else null;
      in {
        keybindings = keybindingsForThisApp;
        windowRules = windowRulesForThisApp;
        scripts = scriptsForThisApp;
        workspaceName = workspaceNameForAllocation;
      }
    )
    processedApps;

  allKeybindings = lib.foldl lib.recursiveUpdate {} (map (cfg: cfg.keybindings or {}) generatedWMConfigsPerApp);
  allWindowRules = lib.flatten (map (cfg: cfg.windowRules or []) generatedWMConfigsPerApp);
  allScripts = lib.flatten (map (cfg: cfg.scripts or []) generatedWMConfigsPerApp);

  browserWorkspaceScripts = lib.map mkBrowserWorkspaceScript sortedWorkspaceNames;

  browserKeybindings = lib.listToAttrs (
    lib.imap0 (idx: workspaceName: {
      name = "ISO_Level5_Shift+Control+${
        # Use the original key for the keybinding, not the transformed workspace name
        lib.replaceStrings ["ws-"] [""] workspaceName
      }";
      value.action.spawn = [
        "${lib.elemAt browserWorkspaceScripts idx}/bin/browser-to-${lib.strings.sanitizeDerivationName workspaceName}"
      ];
    })
    sortedWorkspaceNames
  );
in
  lib.mkMerge [
    {
      environment.systemPackages =
        allScripts
        ++ browserWorkspaceScripts
        ++ [
          pkgs.ripgrep
          pkgs.jq # Add jq for JSON parsing
        ];
    }

    (wmConstants.setSettings {
      binds = lib.recursiveUpdate allKeybindings browserKeybindings;
      window-rules = allWindowRules;
      workspaces = lib.genAttrs sortedWorkspaceNames (_name: {});
    })
  ]
