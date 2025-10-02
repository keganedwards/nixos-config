{
  config,
  lib,
  username,
  ...
}: let
  wmConstants = config.windowManagerConstants;
  escapeRegex = str: lib.escapeRegex str;
  processedApps = config.applications or {};

  generatedWMConfigsPerApp =
    lib.mapAttrsToList (
      appKeyFromConfig: appConfig: let
        bindingKey = appConfig.key or appKeyFromConfig;
        workspaceName = appConfig.swayWorkspace or bindingKey;
        launchCmd = appConfig.launchCommand or null;
        appIdCriteria = appConfig.appId or null;

        keybindingsForThisApp =
          if launchCmd != null && lib.hasPrefix "exec " launchCmd && bindingKey != null && workspaceName != null
          then {
            "Scroll_Lock+${bindingKey}" = "workspace ${workspaceName}";
            "Scroll_Lock+Shift+${bindingKey}" = "move container to workspace ${workspaceName}";
            "Scroll_Lock+Mod1+${bindingKey}" = "${launchCmd}; workspace ${workspaceName}";
          }
          else {};

        assignmentsForThisApp =
          if appIdCriteria != null && workspaceName != null
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

        windowRulesForThisApp =
          if appIdCriteria != null && workspaceName != null
          then let
            appIdList =
              if lib.isList appIdCriteria
              then appIdCriteria
              else [appIdCriteria];
          in
            lib.flatten (lib.map (idString: [
                (wmConstants.window.workspaceRule idString workspaceName)
              ])
              appIdList)
          else [];
      in {
        keybindings = keybindingsForThisApp;
        assignments = assignmentsForThisApp;
        windowRules = windowRulesForThisApp;
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
in {
  home-manager.users.${username} = lib.setAttrByPath wmConstants.configPath {
    keybindings = lib.mkMerge [
      allKeybindings
    ];
    assigns = allAssigns;
    window.commands = allWindowRules;
  };
}
