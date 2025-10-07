{
  config,
  lib,
  pkgs,
  username,
  windowManagerConstants,  
  ...
}: let
  wmConstants = windowManagerConstants;
  processedApps = config.applications or {};
  
  # Get all workspace names we'll create and sort them alphabetically
  allWorkspaceNames = lib.unique (lib.filter (name: name != null) 
    (lib.mapAttrsToList (_: appConfig: appConfig.workspaceName or appConfig.key or null) processedApps));
  sortedWorkspaceNames = lib.sort (a: b: a < b) allWorkspaceNames;
  
  # Create a mapping of workspace name to its ID (1-indexed to match niri output)
  workspaceNameToId = lib.listToAttrs (lib.imap1 (idx: name: {
    name = name;
    value = idx;
  }) sortedWorkspaceNames);

  # Create workspace navigation script for niri with NAMED workspaces
  mkWorkspaceScript = workspaceName: appConfig: let
    launchCmd = appConfig.launchCommand or null;
    isBlankWorkspace = launchCmd == null;
    workspaceId = workspaceNameToId.${workspaceName} or 999;
    
    scriptContent = 
      if isBlankWorkspace 
      then ''
        #!${pkgs.runtimeShell}
        ${wmConstants.ipc.focusWorkspace workspaceName}
      ''
      else ''
        #!${pkgs.runtimeShell}
        set -e
        
        # Switch to target workspace first
        ${wmConstants.ipc.focusWorkspace workspaceName}
        
        # Check for Alt key modifier (env var set by keybinding)
        if [ "$FORCE_LAUNCH" = "1" ]; then
          ${launchCmd}
          exit 0
        fi
        
        # Check if workspace has any windows using pre-calculated ID
        has_windows=$(${wmConstants.ipc.workspaceHasWindows "${toString workspaceId}"})
        
        # If no windows exist on workspace, launch the app
        if [ "$has_windows" = "false" ]; then
          ${launchCmd}
        fi
      '';
  in pkgs.writeScriptBin "goto-workspace-${lib.strings.sanitizeDerivationName workspaceName}" scriptContent;

  generatedWMConfigsPerApp =
    lib.mapAttrsToList (
      appKeyFromConfig: appConfig: let
        bindingKey = appConfig.key or null;
        # Use the key as the workspace name directly
        workspaceName = appConfig.workspaceName or bindingKey;
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
            # Normal press: focus workspace and launch if empty
            "ISO_Level5_Shift+${bindingKey}".action.spawn = ["${workspaceScript}/bin/${workspaceScript.name}"];
            # Alt+key: force launch app
            "ISO_Level5_Shift+Alt+${bindingKey}".action.spawn = ["sh" "-c" "FORCE_LAUNCH=1 ${workspaceScript}/bin/${workspaceScript.name}"];
            # Shift+key: move current window to workspace
            "ISO_Level5_Shift+Shift+${bindingKey}".action.move-window-to-workspace = workspaceName;
          }
          else {};

        # Window rules tell niri where to place windows when they launch
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

in lib.mkMerge [
  {
    environment.systemPackages = allScripts ++ [pkgs.ripgrep];
  }
  
  (wmConstants.setSettings {
    binds = allKeybindings;
    window-rules = allWindowRules;
    # Dynamically create named workspaces
    workspaces = lib.genAttrs sortedWorkspaceNames (_name: {});
  })
]
