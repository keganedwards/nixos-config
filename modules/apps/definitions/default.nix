{
  lib,
  pkgs,
  config,
  constants,
  helpers,
  inputs,
  username,
  ...
}: let
  importDef = path: let
    content = import path;
  in
    if lib.isFunction content
    then content {inherit lib pkgs config constants helpers inputs username;}
    else content;

  appDefinitionOutputs = [
    (importDef ./bracketleft-torrent-music.nix)
    (importDef ./bracketright-torrent-general.nix)
    (importDef ./browser/w-writing-assistant-pwa.nix)
    (importDef ./e-text-editor)
    (importDef ./r-document-reader.nix)
    (importDef ./t-terminal)
    (importDef ./y-virtualization.nix)
    (importDef ./u-spreadsheet-calculator.nix)
    (importDef ./i-image-viewer.nix)
    (importDef ./o-screen-recorder.nix)
    (importDef ./browser/p-private-browser.nix)
    (importDef ./browser/backslash-ai-studio-pwa.nix)
    (importDef ./2-private-messenger.nix)
    (importDef ./browser/3-discord-pwa.nix)
    (importDef ./4-sms.nix)
    (importDef ./browser/5-email-pwa.nix)
    (importDef ./6-clock.nix)
    (importDef ./browser/7-cloud-storage-pwa.nix)
    (importDef ./8-system-monitor.nix)
    (importDef ./browser/9-background-streams-pwa.nix)
    (importDef ./browser/0-weather-forecast-webapp.nix)
    (importDef ./s-audio-controller.nix)
    (importDef ./d-draw-tool.nix)
    (importDef ./g-games.nix)
    (importDef ./browser/h-source-control-pwa.nix)
    (importDef ./browser/j-job-portal-webapp.nix)
    (importDef ./browser/k-financial-portal-webapp.nix)
    (importDef ./l-llm-client.nix)
    (importDef ./semicolon-word-processor.nix)
    (importDef ./apostrophe-ebook-reader.nix)
    (importDef ./x-game-launcher.nix)
    (importDef ./browser/c-calendar-pwa.nix)
    (importDef ./media-player/v-video-player.nix)
    (importDef ./browser/b-default-browser.nix)
    (importDef ./media-player/m-music-player.nix)
    (importDef ./browser/comma-social-media-pwa.nix)
    (importDef ./period-network-tui.nix)
    (importDef ./n-gitui.nix)
    (importDef ./browser/backspace-file-sync-manager.nix)
    (importDef ./media-player/_config-media-player.nix)
  ];
in
  lib.foldl lib.recursiveUpdate {} appDefinitionOutputs
