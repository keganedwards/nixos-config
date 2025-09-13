# This file uses a manual, curated list for a clear overview of all definitions,
# and then uses intelligent logic to process them correctly.
{
  lib,
  pkgs,
  config,
  constants,
  helpers,
  inputs,
  ...
}: let
  # --- Part 1: Your Preferred Manual Import Style with a Smart Helper ---
  # It checks if the imported file returns a function. If it does, it calls it
  # with the necessary arguments. If it's just a raw attribute set, it returns it directly.
  # This makes the loader compatible with BOTH simple and complex definition files.
  importDef = path: let
    content = import path;
  in
    if lib.isFunction content
    then content {inherit lib pkgs config constants helpers inputs;}
    else content;

  # The manually curated list of all application and configuration definitions.
  appDefinitionOutputs = [
    # --- Top Row (W, E, R, T, Y, U, I, O, P, [, ], \) ---
    (importDef ./browser/w-writing-assistant-pwa.nix)
    (importDef ./e-text-editor)
    (importDef ./r-document-reader.nix)
    (importDef ./t-terminal)
    (importDef ./y-virtualization.nix)
    (importDef ./u-spreadsheet-calculator.nix)
    (importDef ./i-image-viewer.nix)
    (importDef ./o-screen-recorder.nix)
    (importDef ./browser/p-private-browser.nix)
    (importDef ./bracketleft-torrent-music.nix)
    (importDef ./bracketright-torrent-general.nix)
    (importDef ./browser/backslash-ai-studio-pwa.nix)

    # --- Number Row (2, 3, 4, 5, 6, 7, 8, 9, 0, -) ---
    (importDef ./2-private-messenger.nix)
    (importDef ./browser/3-discord-pwa.nix)
    (importDef ./4-sms.nix)
    (importDef ./browser/5-email-pwa.nix)
    (importDef ./6-clock.nix)
    (importDef ./browser/7-cloud-storage-pwa.nix)
    (importDef ./8-system-monitor.nix)
    (importDef ./browser/9-background-streams-pwa.nix)
    (importDef ./browser/0-weather-forecast-webapp.nix)
    (importDef ./browser/minus-diff-tool-pwa.nix)

    # --- Home Row (S, D, F, G, H, J, K, L, ;, ') ---
    (importDef ./s-audio-controller.nix)
    (importDef ./d-draw-tool.nix)
    (importDef ./g-games.nix)
    (importDef ./browser/h-source-control-pwa.nix)
    (importDef ./browser/j-job-portal-webapp.nix)
    (importDef ./browser/k-financial-portal-webapp.nix)
    (importDef ./l-llm-client.nix)
    (importDef ./semicolon-word-processor.nix)
    (importDef ./apostrophe-ebook-reader.nix)

    # --- Bottom Row (X, C, V, B, N, M, ,, .) ---
    (importDef ./x-game-launcher.nix)
    (importDef ./browser/c-calendar-pwa.nix)
    (importDef ./media-player/v-video-player.nix)
    (importDef ./browser/b-default-browser.nix)
    (importDef ./media-player/m-music-player.nix)
    (importDef ./browser/comma-social-media-pwa.nix)
    (importDef ./period-network-tui.nix)
    (importDef ./n-gitui.nix)
    # --- Keyless or Special Key Apps (Daemons, Utilities) ---
    (importDef ./browser/backspace-file-sync-manager.nix)

    # --- Manually Imported Shared Configurations ---
    (importDef ./media-player/_config-media-player.nix)
  ];

  # --- Part 2: The Intelligent Processing Logic (Unchanged) ---
  isSingleAppDefinition = v:
    lib.isAttrs v
    && (v ? "type" || v ? "id" || v ? "launchCommand" || v ? "key");
  partitioned = lib.partition isSingleAppDefinition appDefinitionOutputs;
  singleApps = partitioned.right;
  complexConfigs = partitioned.wrong;

  mergeComplex = lhs: rhs: let
    combinedAppList = (lhs.appList or []) ++ (rhs.appList or []);
    lhsWithoutAppList = lib.removeAttrs lhs ["appList"];
    rhsWithoutAppList = lib.removeAttrs rhs ["appList"];
    mergedRest = lib.recursiveUpdate lhsWithoutAppList rhsWithoutAppList;
  in
    mergedRest // {appList = combinedAppList;};

  mergedComplexConfig = lib.foldl mergeComplex {} complexConfigs;
  finalAppList = singleApps ++ (mergedComplexConfig.appList or []);
in
  # --- Part 3: Final, Clean Output (Unchanged) ---
  (lib.removeAttrs mergedComplexConfig ["appList"]) // {appList = finalAppList;}
