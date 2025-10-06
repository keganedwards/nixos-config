{lib, ...}: {
  options = {
    rawAppDefinitions = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Raw app definitions from individual app modules";
    };

    applications = lib.mkOption {
      description = "Configured applications.";
      default = {};
      type = lib.types.attrsOf (lib.types.submodule {
        options = {
          id = lib.mkOption {
            type = lib.types.str;
            description = "Primary identifier (package name, Flatpak ID, URL, or logical name).";
          };

          type = lib.mkOption {
            type = lib.types.enum ["nix" "flatpak" "pwa" "web-page" "blank" "externally-managed" "custom"];
            default = "externally-managed";
            description = "Application type.";
          };

          key = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Keybinding hint.";
          };

          autostartCommand = lib.mkOption {
            type = lib.types.str;
            description = "Command to use for autostart (defaults to launchCommand).";
          };

          workspaceName = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Workspace name for window manager assignment.";
          };

          ignoreWindowAssignment = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "If true, don't create automatic window assignments or rules for this app.";
          };

          autostart = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Whether to autostart.";
          };

          launchCommand = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Launch command.";
          };

          appId = lib.mkOption {
            type = lib.types.nullOr (lib.types.oneOf [lib.types.str (lib.types.listOf lib.types.str)]);
            default = null;
            description = "Application ID for window management.";
          };

          appInfo = lib.mkOption {
            type = lib.types.submodule {
              options = {
                name = lib.mkOption {
                  type = lib.types.str;
                  description = "Application name.";
                };

                installMethod = lib.mkOption {
                  type = lib.types.enum ["nix-package" "nix-custom-path" "flatpak" "none" "custom"];
                  description = "Installation method.";
                };

                package = lib.mkOption {
                  type = lib.types.str;
                  description = "Package identifier.";
                };

                appId = lib.mkOption {
                  type = lib.types.nullOr (lib.types.oneOf [lib.types.str (lib.types.listOf lib.types.str)]);
                  default = null;
                  description = "Application ID.";
                };

                title = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Window title.";
                };

                isTerminalApp = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Whether terminal app.";
                };
              };
            };
            description = "Application information.";
          };

          desktopFile = lib.mkOption {
            type = lib.types.submodule {
              options = {
                generate = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Generate desktop file.";
                };

                displayName = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Display name.";
                };

                genericName = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Generic name.";
                };

                comment = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Comment.";
                };

                iconName = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Icon name.";
                };

                categories = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = ["Utility"];
                  description = "Categories.";
                };

                defaultAssociations = lib.mkOption {
                  type = lib.types.listOf lib.types.str;
                  default = [];
                  description = "MIME types.";
                };

                isDefaultHandler = lib.mkOption {
                  type = lib.types.bool;
                  default = false;
                  description = "Set as default handler.";
                };

                desktopExecArgs = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Exec arguments.";
                };

                targetDesktopFilename = lib.mkOption {
                  type = lib.types.nullOr lib.types.str;
                  default = null;
                  description = "Target filename.";
                };
              };
            };
            default = {};
            description = "Desktop file configuration.";
          };
        };
      });
    };
  };
}
