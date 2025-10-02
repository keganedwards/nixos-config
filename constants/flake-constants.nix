# ./flake-constants.nix
# Defines truly global constants or those derived purely from pkgs/lib.
# It is imported by flake.nix and should not depend on Home Manager 'config'.
{
  pkgs,
  stateVersion,
  # You could add 'inputs' or 'system' here if some global constants
  # truly depend on other flake inputs or the specific system,
  # but for most of these, 'lib' and 'pkgs' are sufficient.
  ... # Catch-all for any other args passed from flake.nix's mkGlobalConstants
}: let
  # --- Terminal Tools ---
  fileListingTool = "eza";
  fileListingArgs = "-la"; # Just basic args, let HM handle icons/colors
  fuzzyFinder = "fzf";
  directoryJumper = "zoxide";
  gitUiTool = "lazygit"; # Git TUI tool
  builderRepoPath = "/opt/nixos-config";
  builderSshKeyPath = "/opt/ssh/id_ed25519"; # Centralized this as well

  # --- Security: SSH Public Key ---
  # Your GitHub SSH public key for signature verification
  trustedSshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKSRQ9CKzXZ9mfwykoTSxqOAIov20LfQxzyLX+444M1x";

  # --- Terminal Emulator ---
  # These are fixed DEFAULTS based on the 'pkgs' for the current system.
  # If user configuration (e.g., config.programs.foot.package) needs to be respected,
  # that logic must happen in the consuming module (e.g., helpers or app definitions)
  # by comparing with these defaults.
  defaultTerminalPackageName = "foot"; # The command name
  _defaultTerminalActualPackage = pkgs.${defaultTerminalPackageName};
  defaultTerminalBinPath = "${_defaultTerminalActualPackage}/bin/${defaultTerminalPackageName}";
  terminalLaunchCmd = "${defaultTerminalBinPath} --app-id=";

  # --- Editor ---
  # These are conventions or specific IDs, not dependent on live HM 'config'
  editorAppIdForSway = "nvim-editor-terminal"; # Your chosen Sway app_id for the terminal hosting nvim
  editorNixPackageName = "neovim"; # Conventional Nix package name for Neovim base
  editorIconName = "nvim"; # Default icon name for editor .desktop files

  # --- Video Player (MPV) ---
  defaultMpvPackageName = "mpv";
  _defaultMpvActualPackage = pkgs.${defaultMpvPackageName};
  defaultVideoPlayerBinPath = "${_defaultMpvActualPackage}/bin/${defaultMpvPackageName}";
  videoPlayerAppId = "mpv"; # Sway app_id for MPV

  # --- Browser/PWA ---
  defaultWebbrowserFlatpakId = "com.brave.Browser"; # Your chosen default browser Flatpak ID
  # CRITICAL: This WM_CLASS must match what your default browser (Brave) actually uses.
  # Verify with `swaymsg -t get_tree` when Brave is open.
  # Common values are "Brave-browser", "brave-browser".
  defaultWebbrowserWmClass = "Brave-browser";
  pwaRunnerFlatpakId = defaultWebbrowserFlatpakId; # PWA runner is the default browser
  pwaRunnerWmClass = defaultWebbrowserWmClass; # WM_CLASS of the PWA runner

  # --- Syncthing ---
  syncthingGuiUrl = "http://127.0.0.1:8384";

  # --- Utility Packages (Direct references to pkgs attributes) ---
  screenshotUtilitySlurp = pkgs.slurp;
  screenshotUtilityGrim = pkgs.grim;
  clipboardUtilityWlClipboard = pkgs.wl-clipboard;
  generalUtilityCoreutils = pkgs.coreutils;

  # --- Common MIME types (Static lists) ---
  commonTextEditorMimeTypes = [
    "text/plain"
    "text/markdown"
    "text/html"
    "text/css"
    "text/csv"
    "text/tab-separated-values"
    "text/calendar"
    "text/vcard"
    "text/troff"
    "text/x-rst"
    "text/x-tex"
    "text/asciidoc"
    "text/x-devicetree-source"
    "application/json"
    "application/toml"
    "application/x-yaml"
    "text/x-ini"
    "text/x-properties"
    "text/x-systemd-unit"
    "application/xml"
    "text/xml"
    "application/x-desktop"
    "text/x-ignore"
    "text/x-editorconfig"
    "text/x-shellscript"
    "text/x-fish"
    "application/x-fishscript"
    "text/x-python"
    "application/x-python-code"
    "text/x-perl"
    "text/x-ruby"
    "application/javascript"
    "text/javascript"
    "application/typescript"
    "text/typescript"
    "text/x-lua"
    "application/x-php"
    "text/x-tcl"
    "application/x-awk"
    "application/x-powershell"
    "text/x-csrc"
    "text/x-chdr"
    "text/x-c++src"
    "text/x-c++hdr"
    "text/x-java-source"
    "text/x-csharp"
    "text/x-go"
    "text/x-rustsrc"
    "text/x-haskell"
    "text/x-literate-haskell"
    "text/x-nix"
    "text/x-cmake"
    "text/x-makefile"
    "application/sql"
    "text/x-sql"
    "text/x-diff"
    "text/x-patch"
    "text/x-ocaml"
    "text/x-scala"
    "text/x-swift"
    "text/x-kotlin"
    "application/pgp-keys"
    "application/pgp-signature"
    "application/ld+json"
    "text/x-log"
  ];
  videoMimeTypes = [
    "video/mpeg"
    "video/mp4"
    "video/quicktime"
    "video/x-msvideo"
    "video/x-matroska"
    "video/webm"
    "video/ogg"
    "video/x-flv"
    "video/x-ms-wmv"
    "application/vnd.rn-realmedia"
    "application/vnd.apple.mpegurl"
    "application/dash+xml"
    "video/x-m4v"
    "video/3gpp"
    "video/x-theora+ogg"
    "video/x-ogm+ogg"
    "video/x-flc"
    "video/x-fli"
    "video/x-nuv"
    "video/vnd.vivo"
    "video/wavelet"
    "video/x-anim"
    "video/x-nsv"
    "video/x-real-video"
    "video/x-sgi-movie"
    "video/x-motion-jpeg"
    "video/x-dv"
    "video/x-cdg"
  ];
  audioMimeTypes = [
    "audio/mpeg"
    "audio/ogg"
    "audio/aac"
    "audio/flac"
    "audio/wav"
    "audio/x-ms-wma"
    "audio/opus"
    "audio/vorbis"
    "audio/x-matroska"
    "audio/mp4"
    "application/ogg"
    "audio/aacp"
    "audio/x-musepack"
    "audio/x-tta"
    "audio/x-aiff"
    "audio/x-ape"
    "audio/x-vorbis+ogg"
    "audio/x-flac+ogg"
    "audio/x-speex+ogg"
    "audio/x-scpls"
    "audio/x-mpegurl"
    "audio/vnd.rn-realaudio"
    "audio/x-realaudio"
    "audio/x-s3m"
    "audio/x-stm"
    "audio/x-it"
    "audio/x-xm"
    "audio/x-mod"
    "audio/midi"
  ];
  imageMimeTypes = [
    "image/jpeg"
    "image/png"
    "image/gif"
    "image/webp"
    "image/bmp"
    "image/svg+xml"
    "image/tiff"
    "image/avif"
    "image/jxl"
    "image/x-icon"
    "image/vnd.djvu"
    "image/x-portable-pixmap"
    "image/x-portable-anymap"
    "image/x-portable-bitmap"
    "image/x-portable-graymap"
    "image/x-tga"
    "image/x-pcx"
    "image/x-xbm"
    "image/x-xpm"
    "image/x-cmu-raster"
    "image/x-photo-cd"
    "image/heif"
    "image/heic"
  ];

  # --- App Specific Package Names (if needed as constants) ---
  fileManagerNixPackageName = "yazi"; # Default name for Yazi package
in {
  inherit stateVersion;
  # --- Security ---
  inherit trustedSshPublicKey;

  # --- Terminal Related ---
  # These provide information about the *default* terminal package.
  # Consuming modules should check 'config.programs.foot.package' for user overrides.
  terminalName = defaultTerminalPackageName; # The command/logical name (e.g., "foot")
  terminalBin = defaultTerminalBinPath; # Path to the default terminal's binary
  terminalPackage = _defaultTerminalActualPackage; # The derivation of the default terminal
  inherit terminalLaunchCmd;

  # --- Editor Related ---
  inherit editorAppIdForSway editorNixPackageName editorIconName;

  # --- Video Player Related ---

  inherit fileListingTool fileListingArgs fuzzyFinder directoryJumper gitUiTool;

  # These provide information about the *default* MPV package.
  # Consuming modules should check 'config.programs.mpv.package' for user overrides.
  mpvPackage = _defaultMpvActualPackage; # Default MPV package derivation
  videoPlayerName = defaultMpvPackageName; # The command/logical name (e.g., "mpv")
  videoPlayerBin = defaultVideoPlayerBinPath; # Path to default MPV binary
  inherit videoPlayerAppId; # Sway app_id for MPV

  # --- Browser/PWA ---
  inherit defaultWebbrowserFlatpakId defaultWebbrowserWmClass;
  inherit pwaRunnerFlatpakId pwaRunnerWmClass;

  # --- Syncthing ---
  inherit syncthingGuiUrl;

  # --- Utility Packages (exporting the derivations directly) ---
  inherit
    screenshotUtilitySlurp
    screenshotUtilityGrim
    clipboardUtilityWlClipboard
    generalUtilityCoreutils
    ;

  inherit builderRepoPath builderSshKeyPath;

  # --- MIME Types ---
  inherit commonTextEditorMimeTypes imageMimeTypes audioMimeTypes videoMimeTypes;

  # --- Other App Specific Constants ---
  inherit fileManagerNixPackageName;
}
