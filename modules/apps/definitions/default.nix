let
  # Simply import all app definitions as modules
  appDefinitionOutputs = [
    ./bracketleft-torrent-music.nix
    ./bracketright-torrent-general.nix
    ./browser/w-writing-assistant-pwa.nix
    ./text-editor
    ./r-document-reader.nix
    ./t-terminal
    ./y-virtualization.nix
    ./u-spreadsheet-calculator.nix
    ./i-image-viewer.nix
    ./o-screen-recorder.nix
    ./browser/p-private-browser.nix
    ./browser/backslash-cloud-ai.nix
    ./2-private-messenger.nix
    ./browser/3-discord-pwa.nix
    ./4-sms.nix
    ./browser/5-email-pwa.nix
    ./6-clock.nix
    ./browser/7-cloud-storage-pwa.nix
    ./8-system-monitor.nix
    ./browser/9-background-streams-pwa.nix
    ./browser/0-weather-forecast-webapp.nix
    ./s-audio-controller.nix
    ./d-draw-tool.nix
    ./g-games.nix
    ./browser/h-source-control-pwa.nix
    ./browser/j-job-portal-webapp.nix
    ./browser/k-financial-portal-webapp.nix
    ./l-llm-client.nix
    ./semicolon-word-processor.nix
    ./apostrophe-ebook-reader.nix
    ./x-game-launcher.nix
    ./browser/c-calendar-pwa.nix
    ./media-player/v-video-player.nix
    ./browser/b-default-browser.nix
    ./media-player/m-music-player.nix
    ./browser/comma-social-media-pwa.nix
    ./period-network-tui.nix
    ./browser/backspace-file-sync-manager.nix
    ./media-player/_config-media-player.nix
  ];
in {
  imports = appDefinitionOutputs;
}
