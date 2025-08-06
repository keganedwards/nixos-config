# ./modules/home-manager/systemd/bing-wallpaper.nix
{
  pkgs,
  config,
  ...
}: let
  # Use XDG Base Directory Specification for user data (default: ~/.local/share)
  wallpaperDir = "${config.xdg.dataHome}/wallpapers/Bing";
  wallpaperPath = "${wallpaperDir}/desktop.jpg";
  lockscreenPath = "${wallpaperDir}/lockscreen.jpg";

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
      procps # For pkill
    ];
    text = ''
      #!/usr/bin/env bash
      set -euo pipefail

      # --- Config ---
      # Paths are injected directly from Nix using interpolated variables above
      TARGET_DIR="${wallpaperDir}"
      WALLPAPER_PATH="${wallpaperPath}"
      LOCKSCREEN_PATH="${lockscreenPath}"

      # Ensure target directory exists (user service has permission)
      mkdir -p "$TARGET_DIR"

      # --- Helper: Get Sway Resolution ---
      get_monitor_resolution() {
        # SWAYSOCK should be passed by systemd user service environment
        if [ -z "''${SWAYSOCK:-}" ]; then echo "Error: SWAYSOCK not set" >&2; return 1; fi
        timeout 10s swaymsg -t get_outputs | \
          jq -r '[.[] | select(.active == true) | .current_mode.width, .current_mode.height] | select(length==2) | "\(.[0])x\(.[1])"' | head -n 1
      }

      # --- Main Logic ---
      echo "=== Bing Wallpaper Start ($(date)) ==="
      echo "Target: $TARGET_DIR"

      monitor_resolution=$(get_monitor_resolution) || { echo "Error: Resolution failed" >&2; exit 1; }
      if [ -z "$monitor_resolution" ]; then
        echo "Warn: No resolution detected, using 1920x1080" >&2
        monitor_resolution="1920x1080"
      fi
      echo "Resolution: $monitor_resolution"

      # --- Check if Download Needed ---
      should_download=false
      if [ -f "$WALLPAPER_PATH" ]; then
          file_date=$(date -r "$WALLPAPER_PATH" +%Y-%m-%d)
          today=$(date +%Y-%m-%d)
          if [ "$file_date" != "$today" ]; then
              echo "Outdated. Downloading."
              should_download=true
          # else # Already up-to-date
              # echo "Already up-to-date." # Uncomment if verbose log desired
          fi
      else
          echo "Missing. Downloading."
          should_download=true
      fi

      # --- Download & Process ---
      if [ "$should_download" = true ]; then
          echo "Downloading..."
          bing_base_url="https://www.bing.com"
          TMP_WALLPAPER=$(mktemp --tmpdir="$TARGET_DIR" --suffix=.jpg)
          trap 'rm -f "$TMP_WALLPAPER"' EXIT # Cleanup temp file

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
          rm -f "$TMP_WALLPAPER"; trap - EXIT # Remove temp, clear trap

          echo "Generating lockscreen image..."
          if ! timeout 60s magick "$WALLPAPER_PATH" -filter Gaussian -blur 0x8 -level 10%,90%,0.5 "$LOCKSCREEN_PATH"; then
              echo "Warn: Lockscreen generation failed" >&2
          fi
          echo "Download & process complete."
      fi

      # --- Set Wallpaper (always attempt if file exists) ---
      if [ -f "$WALLPAPER_PATH" ]; then
         echo "Setting wallpaper via swaymsg..."
         pkill swaybg || true # Kill previous instances
         if ! timeout 10s swaymsg "output * bg \"$WALLPAPER_PATH\" fill"; then
            echo "Warn: swaymsg failed. Is Sway running?" >&2
         else
            echo "Wallpaper set."
         fi
      else
         echo "Error: Final wallpaper '$WALLPAPER_PATH' not found. Cannot set." >&2
         exit 1
      fi

      echo "=== Bing Wallpaper End ($(date)) ==="
      exit 0
    '';
  }; # End writeShellApplication
in {
  # Systemd user service (managed by Home Manager)
  systemd.user.services.bing-wallpaper = {
    Unit = {
      Description = "Bing Wallpaper Fetcher/Setter";
      After = ["graphical-session.target" "network-online.target" "time-sync.target"];
      Wants = ["network-online.target"];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${bingWallpaperScript}/bin/bing-wallpaper-hm";
      # Pass needed environment variables for user session interaction
      PassEnvironment = [
        "DISPLAY"
        "WAYLAND_DISPLAY"
        "SWAYSOCK"
        "XDG_RUNTIME_DIR"
        "DBUS_SESSION_BUS_ADDRESS"
        "HOME"
      ];
    };
    # Not explicitly started/stopped, relies on timer
  };

  # Systemd user timer (managed by Home Manager)
  systemd.user.timers.bing-wallpaper = {
    Unit = {
      Description = "Run Bing Wallpaper Service Daily";
    };
    Timer = {
      OnCalendar = "daily"; # Run once a day
      Persistent = true; # Run on next login if missed
      RandomizedDelaySec = "15m"; # Stagger load
    };
    Install = {
      WantedBy = ["timers.target"]; # Enable the timer
    };
  };
}
