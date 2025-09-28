{
  pkgs,
  config,
  ...
}: let
  wallpaperDir = "${config.xdg.dataHome}/wallpapers/Bing";
  wallpaperPath = "${wallpaperDir}/desktop.jpg";
  lockscreenPath = "${wallpaperDir}/lockscreen.jpg";

  # Define the script that fetches the wallpaper
  bingWallpaperScript = pkgs.writeShellApplication {
    name = "bing-wallpaper-hm";
    runtimeInputs = with pkgs; [
      coreutils
      bash
      jq
      curl
      imagemagick
      sway # For swaymsg
      gnugrep
      findutils
    ];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      TARGET_DIR="${wallpaperDir}"
      WALLPAPER_PATH="${wallpaperPath}"
      LOCKSCREEN_PATH="${lockscreenPath}"

      mkdir -p "$TARGET_DIR"

      get_monitor_resolution() {
        if [ -z "''${SWAYSOCK:-}" ]; then echo "Error: SWAYSOCK not set" >&2; return 1; fi
        timeout 10s swaymsg -t get_outputs | \
          jq -r '[.[] | select(.active == true) | .current_mode.width, .current_mode.height] | select(length==2) | "\(.[0])x\(.[1])"' | head -n 1
      }

      echo "=== Bing Wallpaper Start ($(date)) ==="
      echo "Target: $TARGET_DIR"

      should_download=false
      if [ ! -f "$WALLPAPER_PATH" ]; then
          echo "Wallpaper missing or directory is empty. Downloading."
          should_download=true
      else
          file_date=$(date -r "$WALLPAPER_PATH" +%Y-%m-%d)
          today=$(date +%Y-%m-%d)
          if [ "$file_date" != "$today" ]; then
              echo "Wallpaper is outdated. Downloading."
              should_download=true
          else
              echo "Wallpaper is already up-to-date."
          fi
      fi

      if [ "$should_download" = true ]; then
          monitor_resolution=$(get_monitor_resolution) || { echo "Error: Resolution failed" >&2; exit 1; }
          if [ -z "$monitor_resolution" ]; then
            echo "Warn: No resolution detected, using 1920x1080" >&2
            monitor_resolution="1920x1080"
          fi
          echo "Resolution: $monitor_resolution"

          echo "Downloading..."
          bing_base_url="https://www.bing.com"
          TMP_WALLPAPER=$(mktemp --tmpdir="$TARGET_DIR" --suffix=.jpg)
          trap 'rm -f "$TMP_WALLPAPER"' EXIT

          wallpaper_uri_path=$(curl -sfL --connect-timeout 10 "$bing_base_url/HPImageArchive.aspx?format=js&idx=0&n=1" | jq -re '.images[0].url') || {
               echo "Error: Bing API query failed" >&2; exit 1;
           }
          if [ -z "$wallpaper_uri_path" ]; then echo "Error: Empty URI from API" >&2; exit 1; fi

          curl -sfL --connect-timeout 30 "$bing_base_url$wallpaper_uri_path" -o "$TMP_WALLPAPER" || {
               echo "Error: Image download failed" >&2; exit 1;
           }

          echo "Resizing to $monitor_resolution..."
          if ! timeout 60s magick "$TMP_WALLPAPER" -resize "''${monitor_resolution}!" "$WALLPAPER_PATH"; then
              echo "Error: Resize failed" >&2; rm -f "$TMP_WALLPAPER"; exit 1;
          fi
          rm -f "$TMP_WALLPAPER"; trap - EXIT

          echo "Generating lockscreen image..."
          if ! timeout 60s magick "$WALLPAPER_PATH" -filter Gaussian -blur 0x8 -level 10%,90%,0.5 "$LOCKSCREEN_PATH"; then
              echo "Warn: Lockscreen generation failed" >&2
          fi
          echo "Download & process complete."
      fi

      if [ -f "$WALLPAPER_PATH" ]; then
         echo "Setting wallpaper for live session via swaymsg..."
         if ! timeout 10s swaymsg "output * bg \"$WALLPAPER_PATH\" fill"; then
            echo "Warn: swaymsg failed. Is Sway running?" >&2
         else
            echo "Live wallpaper set."
         fi
      else
         echo "Error: Final wallpaper '$WALLPAPER_PATH' not found. Cannot set." >&2
         exit 1
      fi

      echo "=== Bing Wallpaper End ($(date)) ==="
      exit 0
    '';
  };
in {
  systemd.user.services.bing-wallpaper = {
    Unit = {
      Description = "Bing Wallpaper Fetcher/Setter";
      After = ["graphical-session.target" "network-online.target" "time-sync.target"];
      Wants = ["network-online.target"];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${bingWallpaperScript}/bin/bing-wallpaper-hm";
      PassEnvironment = [
        "DISPLAY"
        "WAYLAND_DISPLAY"
        "SWAYSOCK"
        "XDG_RUNTIME_DIR"
        "DBUS_SESSION_BUS_ADDRESS"
        "HOME"
      ];
    };
  };

  systemd.user.timers.bing-wallpaper = {
    Unit = {
      Description = "Run Bing Wallpaper Service Daily";
    };
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
    Install = {
      WantedBy = ["timers.target"];
    };
  };
  wayland.windowManager.sway.config.startup = [
    {
      command = "swaymsg 'output * bg ${config.home.homeDirectory}/.local/share/wallpapers/Bing/desktop.jpg fill'";
    }
  ];
}
