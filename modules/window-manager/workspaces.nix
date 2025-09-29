{
  config,
  lib,
  username,
  ...
}: let
  escapeRegex = str: lib.escapeRegex str;
  processedApps = config.applications or {};

  generatedSwayConfigsPerApp =
    lib.mapAttrsToList (
      appKeyFromConfig: appConfig: let
        bindingKey = appConfig.key or appKeyFromConfig;
        workspaceName = appConfig.swayWorkspace or bindingKey;
        launchCmd = appConfig.launchCommand or null;
        swayAppIdCriteria = appConfig.appId or null;

        keybindingsForThisApp =
          if launchCmd != null && lib.hasPrefix "exec " launchCmd && bindingKey != null && workspaceName != null
          then {
            "Scroll_Lock+${bindingKey}" = "workspace ${workspaceName}";
            "Scroll_Lock+Shift+${bindingKey}" = "move container to workspace ${workspaceName}";
            # Launch app AND switch to its workspace
            "Scroll_Lock+Mod1+${bindingKey}" = "${launchCmd}; workspace ${workspaceName}";
          }
          else {};

        assignmentsForThisApp =
          if swayAppIdCriteria != null && workspaceName != null
          then let
            appIdList =
              if lib.isList swayAppIdCriteria
              then swayAppIdCriteria
              else [swayAppIdCriteria];
            criteriaList = lib.map (idString: {app_id = "^${escapeRegex idString}$";}) appIdList;
          in
            if criteriaList != []
            then {"${workspaceName}" = criteriaList;}
            else {}
          else {};

        # Only move window to workspace, don't auto-switch to it
        windowRulesForThisApp =
          if swayAppIdCriteria != null && workspaceName != null
          then let
            appIdList =
              if lib.isList swayAppIdCriteria
              then swayAppIdCriteria
              else [swayAppIdCriteria];
          in
            lib.flatten (lib.map (idString: [
                {
                  command = "move container to workspace ${workspaceName}";
                  criteria = {
                    app_id = "^${escapeRegex idString}$";
                  };
                }
                # REMOVED: The auto-switch rule that was causing the issue
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

  allKeybindings = lib.foldl lib.recursiveUpdate {} (map (cfg: cfg.keybindings or {}) generatedSwayConfigsPerApp);

  allAssigns = lib.foldl (
    acc: currentEntryAssignments:
      lib.foldl (
        innerAcc: workspace:
          if lib.hasAttr workspace innerAcc
          then innerAcc // {${workspace} = innerAcc.${workspace} ++ currentEntryAssignments.${workspace};}
          else innerAcc // {${workspace} = currentEntryAssignments.${workspace};}
      )
      acc (lib.attrNames currentEntryAssignments)
  ) {} (map (cfg: cfg.assignments or {}) generatedSwayConfigsPerApp);

  allWindowRules = lib.flatten (map (cfg: cfg.windowRules or []) generatedSwayConfigsPerApp);
in {
  home-manager.users.${username} = {
    wayland.windowManager.sway.config = {
      keybindings = lib.mkMerge [
        allKeybindings
      ];
      assigns = allAssigns;
      window.commands = allWindowRules;
    };
  };
}
