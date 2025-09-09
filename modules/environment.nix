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
      ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    };
  };
}
