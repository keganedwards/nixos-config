{
  pkgs,
  config,
  username,
  lib,
  windowManagerConstants,
  ...
}: let
  hmConfig = config.home-manager.users.${username};
  wallpaperDir = "${hmConfig.xdg.dataHome}/wallpapers/Bing";
  wallpaperPath = "${wallpaperDir}/desktop.jpg";
  lockscreenPath = "${wallpaperDir}/lockscreen.jpg";
  wmConstants = windowManagerConstants;

  # Script that only downloads/updates the wallpaper
  bingWallpaperDownloadScript = pkgs.writeShellApplication {
    name = "bing-wallpaper-download";
    runtimeInputs = with pkgs; [
      coreutils
      bash
      jq
      curl
      imagemagick
    ];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      TARGET_DIR="${wallpaperDir}"
      WALLPAPER_PATH="${wallpaperPath}"
      LOCKSCREEN_PATH="${lockscreenPath}"

      mkdir -p "$TARGET_DIR"

      get_monitor_resolution() {
        timeout 10s ${wmConstants.ipc.getOutputs} | \
          jq -r 'to_entries | .[0] | .value.current_mode | "\(.width)x\(.height)"' 2>/dev/null || echo ""
      }

      echo "=== Bing Wallpaper Download Start ($(date)) ==="
      echo "Target: $TARGET_DIR"

      should_download=false
      if [ ! -f "$WALLPAPER_PATH" ]; then
          echo "Wallpaper missing. Downloading."
          should_download=true
      else
          file_date=$(date -r "$WALLPAPER_PATH" +%Y-%m-%d)
          today=$(date +%Y-%m-%d)
          if [ "$file_date" != "$today" ]; then
              echo "Wallpaper is outdated. Downloading."
              should_download=true
          else
              echo "Wallpaper is already up-to-date."
              exit 0
          fi
      fi

      if [ "$should_download" = true ]; then
          monitor_resolution=$(get_monitor_resolution)
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
          echo "Download complete. Wallpaper updated."
      fi

      echo "=== Bing Wallpaper Download End ($(date)) ==="
      exit 0
    '';
  };
in lib.mkMerge [
  {
    home-manager.users.${username} = {
      home.packages = [pkgs.swaybg];
      
      # Persistent swaybg service
      systemd.user.services.swaybg = {
        Unit = {
          Description = "Wallpaper daemon (swaybg)";
          After = ["graphical-session.target"];
          PartOf = ["graphical-session.target"];
        };
        Service = {
          Type = "simple";
          ExecStart = "${pkgs.swaybg}/bin/swaybg -i ${wallpaperPath} -m fill";
          Restart = "on-failure";
          PassEnvironment = wmConstants.session.envVars;
        };
        Install = {
          WantedBy = ["graphical-session.target"];
        };
      };
      
      # Download service (oneshot, restarts swaybg after download)
      systemd.user.services.bing-wallpaper-download = {
        Unit = {
          Description = "Bing Wallpaper Download";
          After = ["network-online.target" "swaybg.service"];
          Wants = ["network-online.target"];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${bingWallpaperDownloadScript}/bin/bing-wallpaper-download";
          # Restart swaybg after downloading to show new wallpaper
          ExecStartPost = "${pkgs.systemd}/bin/systemctl --user restart swaybg.service";
          PassEnvironment = wmConstants.session.envVars ++ ["XDG_RUNTIME_DIR" "HOME"];
        };
      };

      # Timer for daily downloads
      systemd.user.timers.bing-wallpaper-download = {
        Unit = {
          Description = "Daily Bing Wallpaper Download";
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
      
      # Download wallpaper on login (after a delay to ensure network is ready)
      systemd.user.services.bing-wallpaper-on-login = {
        Unit = {
          Description = "Download Bing Wallpaper on Login";
          After = ["graphical-session.target" "network-online.target" "swaybg.service"];
          Wants = ["network-online.target"];
        };
        Service = {
          Type = "oneshot";
          ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
          ExecStart = "${bingWallpaperDownloadScript}/bin/bing-wallpaper-download";
          ExecStartPost = "${pkgs.systemd}/bin/systemctl --user restart swaybg.service";
          PassEnvironment = wmConstants.session.envVars ++ ["XDG_RUNTIME_DIR" "HOME"];
        };
        Install = {
          WantedBy = ["graphical-session.target"];
        };
      };
    };
  }
]
