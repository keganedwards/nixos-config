# File: modules/nixos/environment.nix
# Purpose: Configures system-wide environment variables and settings.
#          Installs a static list of essential system-level packages.
# Arguments received by this NixOS module (from specialArgs):
{pkgs, ...}: {
  environment = {
    # These packages are available system-wide.
    # User-specific tools should be managed by home-manager.
    systemPackages = with pkgs; [
      neovim # System default editor
      clevis # For automated decryption (e.g., LUKS+TPM)
      ydotool # Command-line tool for input device automation
      keyd # System-level key remapping daemon
    ];

    variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      # You might also want to set SUDO_EDITOR if EDITOR/VISUAL isn't respected by sudoedit
      # in some specific edge cases, though EDITOR should usually suffice.
      # SUDO_EDITOR = "nvim";
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    };
  };
}
