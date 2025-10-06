{
  config,
  lib,
  pkgs,
  username,
  ...
}: let
  wmConstants = config.windowManagerConstants;
  terminalConstants = config.terminalConstants;
  processedApps = config.applications or {};

  # Create a workspace navigation script that launches apps if not present
  mkWorkspaceScript = workspace: appConfig: let
    launchCmd = appConfig.launchCommand or null;
    
    # Handle blank workspace case - no launch command at all
    isBlankWorkspace = launchCmd == null;
    
    scriptContent = 
      if isBlankWorkspace 
      then ''
        #!${pkgs.runtimeShell}
        ${wmConstants.msg} workspace "${workspace}"
      ''
      else ''
        #!${pkgs.runtimeShell}
        set -e
        
        # Switch to target workspace first
        ${wmConstants.msg} workspace "${workspace}"
        
        # Check for Alt key modifier (env var set by keybinding)
        if [ "$FORCE_LAUNCH" = "1" ]; then
          ${launchCmd}
          exit 0
        fi
        
        # Check if ANY window exists in this workspace (check both nodes and floating_nodes)
        window_count=$(${wmConstants.msg} -t get_tree | ${pkgs.jq}/bin/jq -r --arg workspace "${workspace}" '
          recurse(.nodes[]?, .floating_nodes[]?) |
          select(.type == "workspace" and .name == $workspace) |
          [recurse(.nodes[]?, .floating_nodes[]?) | select(.type == "con" and .name != null)] |
          length')
        
        # If no windows exist in workspace, launch the app
        if [ "$window_count" = "0" ] || [ -z "$window_count" ]; then
          ${launchCmd}
        fi
        # If window exists, we've already switched to the workspace, nothing more to do
      '';
  in pkgs.writeScriptBin "goto-workspace-${lib.strings.sanitizeDerivationName workspace}" scriptContent;

  generatedWMConfigsPerApp =
    lib.mapAttrsToList (
      appKeyFromConfig: appConfig: let
        bindingKey = appConfig.key or appKeyFromConfig;
        workspaceName = appConfig.workspaceName or bindingKey;
        appIdCriteria = appConfig.appId or null;
        launchCmd = appConfig.launchCommand or null;
        ignoreWindowAssignment = appConfig.ignoreWindowAssignment or false;
        
        # Check if this is a blank workspace
        isBlankWorkspace = launchCmd == null;
        
        workspaceScript = 
          if bindingKey != null && workspaceName != null
          then mkWorkspaceScript workspaceName appConfig
          else null;

        keybindingsForThisApp =
          if workspaceScript != null
          then {
            "Scroll_Lock+${bindingKey}" = "exec ${workspaceScript}/bin/${workspaceScript.name}";
            "Scroll_Lock+Alt+${bindingKey}" = "exec FORCE_LAUNCH=1 ${workspaceScript}/bin/${workspaceScript.name}";
            "Scroll_Lock+Shift+${bindingKey}" = "move container to workspace ${workspaceName}";
          }
          else {};

        # Don't create assignments for blank workspaces, web-pages, or apps with ignoreWindowAssignment
        assignmentsForThisApp =
          if !isBlankWorkspace && !ignoreWindowAssignment && appIdCriteria != null && workspaceName != null && appConfig.type != "web-page"
          then let
            appIdList =
              if lib.isList appIdCriteria
              then appIdCriteria
              else [appIdCriteria];
            criteriaList = lib.map (idString: wmConstants.window.criteriaByAppId idString) appIdList;
          in
            if criteriaList != []
            then {"${workspaceName}" = criteriaList;}
            else {}
          else {};

        # Don't create window rules for blank workspaces, web-pages, or apps with ignoreWindowAssignment
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
                  command = "move container to workspace ${workspaceName}";
                  criteria = wmConstants.window.criteriaByAppId idString;
                }
              ])
              appIdList)
          else [];
        
        scriptsForThisApp =
          if workspaceScript != null
          then [workspaceScript]
          else [];
      in {
        keybindings = keybindingsForThisApp;
        assignments = assignmentsForThisApp;
        windowRules = windowRulesForThisApp;
        scripts = scriptsForThisApp;
      }
    )
    processedApps;

  allKeybindings = lib.foldl lib.recursiveUpdate {} (map (cfg: cfg.keybindings or {}) generatedWMConfigsPerApp);
  allAssigns = lib.foldl (
    acc: currentEntryAssignments:
      lib.foldl (
        innerAcc: workspace:
          if lib.hasAttr workspace innerAcc
          then innerAcc // {${workspace} = innerAcc.${workspace} ++ currentEntryAssignments.${workspace};}
          else innerAcc // {${workspace} = currentEntryAssignments.${workspace};}
      )
      acc (lib.attrNames currentEntryAssignments)
  ) {} (map (cfg: cfg.assignments or {}) generatedWMConfigsPerApp);
  allWindowRules = lib.flatten (map (cfg: cfg.windowRules or []) generatedWMConfigsPerApp);
  allScripts = lib.flatten (map (cfg: cfg.scripts or []) generatedWMConfigsPerApp);
in {
  environment.systemPackages = allScripts;
  
  home-manager.users.${username} = lib.setAttrByPath wmConstants.configPath {
    keybindings = lib.mkMerge [
      allKeybindings
    ];
    assigns = allAssigns;
    window.commands = allWindowRules;
  };
}
