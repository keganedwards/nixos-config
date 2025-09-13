# home-manager-modules/sway/workspaces.nix
{
  config, # Full Home Manager config, includes processed config.applications and config.myConstants
  lib,
  ...
}: let
  escapeRegex = str: lib.escapeRegex str; # Helper for Sway criteria
  processedApps = config.applications or {};

  generatedSwayConfigsPerApp =
    lib.mapAttrsToList (
      appKeyFromConfig: appConfig: let
        bindingKey = appConfig.key or appKeyFromConfig;
        workspaceName = appConfig.swayWorkspace or bindingKey; # Assuming appConfig.swayWorkspace might exist for flexibility
        launchCmd = appConfig.launchCommand or null;
        swayAppIdCriteria = appConfig.appId or null;

        keybindingsForThisApp =
          if launchCmd != null && lib.hasPrefix "exec " launchCmd && bindingKey != null && workspaceName != null
          then {
            "Scroll_Lock+${bindingKey}" = "workspace ${workspaceName}";
            "Scroll_Lock+Shift+${bindingKey}" = "move container to workspace ${workspaceName}";
            "Scroll_Lock+Mod1+${bindingKey}" = launchCmd;
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

        # Generate window rules for floating windows
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
                # Optional: Also switch to that workspace when the window opens
                {
                  command = "workspace ${workspaceName}";
                  criteria = {
                    app_id = "^${escapeRegex idString}$";
                  };
                }
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

  # Fix for allAssigns - merge assignment lists properly
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

  # Collect all window rules
  allWindowRules = lib.flatten (map (cfg: cfg.windowRules or []) generatedSwayConfigsPerApp);
in {
  wayland.windowManager.sway.config = {
    keybindings = allKeybindings;
    assigns = allAssigns;
    window.commands = allWindowRules;
    # You could add other global Sway settings here if needed
    # e.g., seat = "* hide_cursor when-typing enable";
  };
}
