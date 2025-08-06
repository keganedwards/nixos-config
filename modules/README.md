# Home Manager Modules

```


## 📦 Module Index
| File / Folder | Purpose |
|---------------|---------|
| default.nix | Central entrypoint. Imports and aggregates all sub‐modules in this directory. |
| applications.nix | Declarative list of "applications" with metadata (name, installMethod, launchCmd, etc.). |
| packages.nix | Reads config.applications to build home.packages (Nix) and hm.managedFlatpaks.ids (Flatpaks). |
| flatpak.nix | Activation script to install/uninstall user Flatpaks based on hm.managedFlatpaks.ids. |
| sops.nix | Helper to decrypt encrypted secrets stored under nixos/secrets/ via SOPS‑Nix. |
| xdg.nix | Sets up XDG environment variables (XDG_CONFIG_HOME, etc.) and creates missing directories. |
| stylix.nix | GTK/Qt theme configuration helpers (e.g. Catppuccin theming). |
| vim.nix | Vim/Neovim plugin and settings module. |
| desktop-entries.nix | Generates custom .desktop files for applications that need manual entries. |
| programs/ | Sub‐modules for specific programs (e.g. programs.fish, programs.mpv, programs.sway). |
| services/ | Home Manager service‑style units (e.g. user Systemd services configurations). |
| scripts/ | Utility scripts (e.g. activation hooks, helper functions) that can be used by other modules. |
| sway/ | Sway‑specific helpers (config fragments, workspace layouts). |
| systemd/ | Systemd user unit templates for services managed via Home Manager. |

## ⚙️ Configuration Options
Each module defines its own options.<namespace> and config.<namespace>:

- **config.applications**
  Map of application identifiers → { appName, installMethod = "nix" | "flatpak" | null, extraArgs? }.

- **config.hm.managedFlatpaks.ids**
  (List of strings) Flatpak App IDs to install. Merged across modules.

- **home.packages**
  Automatically populated from applications.nix and packages.nix.

- **config.sops**
  Keys for decrypting your nixos/secrets/*.sops.yaml.

- **config.xdg**
  xdg.configHome, xdg.dataHome, etc., to override where your dotfiles live.

- Module‐specific options under programs, services, vim, stylix, etc.—refer to each Nix file's top comments for details.

Maintained as part of my personal NixOS flake. Feel free to adapt for your own setup!
