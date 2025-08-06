# Nixos
A single‑flake, declarative NixOS configuration. System services, user applications, and their configurations are managed through Nix. The only prerequisite is NixOS itself.

## 🔍 Overview
- **Single Flake**
  All system modules, Home Manager modules, and package definitions are wired up in `flake.nix`.
- **Modular Configuration**
  System-wide settings are managed under `modules/nixos/`, while user-specific configurations are handled by Home Manager modules in `modules/home-manager/`. Host-specific overrides for `desktop` and `laptop` are located in the `hosts/` directory.
- **Secrets Management**
  Encrypted secrets are stored in the root `secrets/` directory, managed by SOPS‑Nix, and deployed appropriately (e.g., to `/etc/nixos/` for system secrets or to user directories for Home Manager secrets).

## 📁 Repository Layout
├── flake.lock
├── flake.nix
├── hosts
│ ├── desktop
│ │ ├── home-manager
│ │ │ ├── default.nix
│ │ │ ├── directories.nix
│ │ │ ├── kanshi.nix
│ │ │ ├── monitor.nix
│ │ │ ├── packages.nix
│ │ │ └── sway.nix
│ │ └── nixos
│ │ ├── automount.nix
│ │ ├── boot
│ │ │ ├── boot.nix
│ │ │ ├── default.nix
│ │ │ └── hardware-configuration.nix
│ │ ├── default.nix
│ │ └── steam.nix
│ └── laptop
│ ├── home-manager
│ │ ├── battery-notifier.nix
│ │ ├── default.nix
│ │ ├── directories.nix
│ │ ├── kanshi.nix
│ │ └── sway.nix
│ └── nixos
│ ├── boot
│ │ ├── boot.nix
│ │ ├── default.nix
│ │ └── hardware-configuration.nix
│ ├── default.nix
│ └── tlp.nix
├── modules
│ ├── home-manager
│ │ ├── apps
│ │ │ ├── config-apps.nix
│ │ │ ├── config-packages.nix
│ │ │ ├── constants.nix
│ │ │ ├── default.nix
│ │ │ ├── helpers.nix
│ │ │ └── options.nix
│ │ ├── create-dotfiles-symlinks.nix
│ │ ├── default.nix
│ │ ├── desktop-entries.nix
│ │ ├── packages.nix
│ │ ├── programs
│ │ │ ├── btop.nix
│ │ │ ├── default.nix
│ │ │ ├── fish.nix
│ │ │ ├── fuzzel.nix
│ │ │ ├── mpv.nix
│ │ │ ├── nix-index.nix
│ │ │ ├── ssh.nix
│ │ │ ├── terminal.nix
│ │ │ ├── tmux.nix
│ │ │ └── yazi.nix
│ │ ├── README.md
│ │ ├── scripts
│ │ │ ├── config-git-push.nix
│ │ │ ├── default.nix
│ │ │ ├── get-workspace-icon.nix
│ │ │ ├── move-to-scratchpad.nix
│ │ │ ├── README.md
│ │ │ └── run-vpn-app.nix
│ │ ├── services
│ │ │ ├── clipse.nix
│ │ │ ├── default.nix
│ │ │ ├── flatpak.nix
│ │ │ ├── mako.nix
│ │ │ ├── ssh.nix
│ │ │ ├── syncthing.nix
│ │ │ └── udiskie.nix
│ │ ├── sops.nix
│ │ ├── sway
│ │ │ ├── base.nix
│ │ │ ├── default.nix
│ │ │ ├── startup.nix
│ │ │ └── workspaces.nix
│ │ ├── systemd
│ │ │ ├── automatic-system-update-monitor.nix
│ │ │ ├── bing-wallpaper.nix
│ │ │ ├── clean-on-sway-exit.nix
│ │ │ ├── default.nix
│ │ │ ├── dotfiles-sync.nix
│ │ │ ├── kde-monitor-check.nix
│ │ │ ├── syncthing-monitor.nix
│ │ │ └── trash-cleaning.nix
│ │ ├── vim
│ │ │ ├── default.nix
│ │ │ └── vim-options.nix
│ │ └── xdg.nix
│ └── nixos
│ ├── boot.nix
│ ├── cachix.nix
│ ├── default.nix
│ ├── environment.nix
│ ├── fonts.nix
│ ├── hardware.nix
│ ├── i18n.nix
│ ├── networking.nix
│ ├── nix.nix
│ ├── nixpkgs.nix
│ ├── programs.nix
│ ├── root-git-config.nix
│ ├── scripts
│ │ ├── default.nix
│ │ ├── nixos-git-push.nix
│ │ └── nixos-test.nix
│ ├── security.nix
│ ├── services
│ │ ├── default.nix
│ │ ├── greetd.nix
│ │ ├── keyd.nix
│ │ ├── pipewire.nix
│ │ ├── resolved.nix
│ │ └── services.nix
│ ├── sops.nix
│ ├── systemd
│ │ ├── default.nix
│ │ └── nixos-config-sync.nix
│ ├── system.nix
│ ├── time.nix
│ ├── user.nix
│ ├── virtualization.nix
│ └── xdg.nix
├── README.md
└── secrets
├── auth.txt.enc
├── clevis-laptop-secret.jwe.enc
├── id_ed25519.key.enc
├── laptop-secret.jwe
├── my-laptop-secret.jwe
├── README.md
├── root_id_ed25519.key.enc
└── united_states-us-free.ovpn.enc
## 📊 System Monitor Selection Rationale
This outlines the comparative preferences for system monitoring tools:

*   **Mission Center > resources**
    *   Reasoning: Mission Center offers a somewhat less cluttered interface and clearer logical organization. This was a marginal preference.

*   **Mission Center (as the preferred GUI) > btop**
    *   Reasoning: This was a very close decision. While btop's TUI and keyboard-centric operation are strong advantages, Mission Center was ultimately favored. Its availability as a Flatpak (contributing to cleaner software distribution) and its default logical grouping of applications (rather than individual processes) align better with typical daily usage patterns.

*   **btop > htop**
    *   Reasoning: btop presents a more aesthetically pleasing visual interface and provides a slightly broader system overview by default.

*   **htop > top**
    *   Reasoning: htop is considerably more user-friendly and easier to navigate.
