{nixCats, ...}: let
  inherit (nixCats) utils; # Changed from: utils = nixCats.utils;
in {
  # Configure nixCats using the NixOS module
  nixCats = {
    enable = true;

    # Add overlay for any custom plugins
    addOverlays = [
      (utils.standardPluginOverlay {})
    ];

    # Which package names to install
    packageNames = ["nvim"];

    # Path to your lua configuration
    luaPath = "${./.}/nvim";

    # Define your categories using .replace
    categoryDefinitions.replace = {pkgs, ...}: {
      lspsAndRuntimeDeps = {
        general = with pkgs; [
          statix
          deadnix
          alejandra
          nodejs
          tree-sitter
          ripgrep
          fd
          gcc
          texlive.combined.scheme-small
        ];

        lsp = with pkgs; [
          # Nix
          nil
          nixd
          # Lua
          lua-language-server
          # Python
          pyright
          ruff
          black
          # TypeScript/JavaScript
          nodePackages.typescript-language-server
          nodePackages.eslint
          prettierd
          # C#
          omnisharp-roslyn
          # Java
          jdt-language-server
          # R
          rPackages.languageserver
          # Bash
          nodePackages.bash-language-server
          shfmt
          # Markdown
          marksman
          # LaTeX
          texlab
        ];
      };

      startupPlugins = {
        general = with pkgs.vimPlugins; [
          # Core
          plenary-nvim
          nvim-web-devicons

          # UI/Theme
          catppuccin-nvim
          lualine-nvim
          indent-blankline-nvim
          which-key-nvim

          # Treesitter
          nvim-treesitter
          nvim-treesitter-parsers.bash
          nvim-treesitter-parsers.c
          nvim-treesitter-parsers.cpp
          nvim-treesitter-parsers.c_sharp
          nvim-treesitter-parsers.css
          nvim-treesitter-parsers.html
          nvim-treesitter-parsers.java
          nvim-treesitter-parsers.javascript
          nvim-treesitter-parsers.json
          nvim-treesitter-parsers.lua
          nvim-treesitter-parsers.markdown
          nvim-treesitter-parsers.markdown_inline
          nvim-treesitter-parsers.nix
          nvim-treesitter-parsers.python
          nvim-treesitter-parsers.r
          nvim-treesitter-parsers.rust
          nvim-treesitter-parsers.toml
          nvim-treesitter-parsers.typescript
          nvim-treesitter-parsers.vim
          nvim-treesitter-parsers.vimdoc
          nvim-treesitter-parsers.yaml
          nvim-treesitter-textobjects

          # Editor
          nvim-autopairs
          comment-nvim
          vim-surround

          # LSP & Completion
          nvim-lspconfig
          nvim-cmp
          cmp-nvim-lsp
          cmp-buffer
          cmp-path
          cmp-cmdline
          luasnip
          cmp_luasnip
          friendly-snippets

          # Formatting
          conform-nvim

          # Fuzzy finder
          fzf-lua
        ];

        git = with pkgs.vimPlugins; [
          gitsigns-nvim
          vim-fugitive
        ];

        debug = with pkgs.vimPlugins; [
          nvim-dap
          nvim-dap-ui
          nvim-dap-virtual-text
          nvim-dap-python
        ];

        markdown = with pkgs.vimPlugins; [
          render-markdown-nvim
        ];
      };

      optionalPlugins = {
        # Plugins you want available but not loaded at startup
      };

      sharedLibraries = {
        general = with pkgs; [
          # Add any shared libraries if needed
        ];
      };

      python3.libraries = {
        debug = ps:
          with ps; [
            debugpy
          ];
      };

      extraLuaPackages = {
        # Empty or minimal lua packages
      };

      environmentVariables = {
        general = {
          # Any environment variables you want set
        };
      };

      extraWrapperArgs = {
        # Don't add gcc to PATH in wrapper, it causes issues
      };
    };

    # Package definitions using .replace
    packageDefinitions.replace = {
      nvim = _: {
        # Changed from: nvim = {...}: {
        settings = {
          wrapRc = true;
          aliases = ["vi" "vim"];
        };

        categories = {
          general = true;
          lsp = true;
          debug = true;
          git = true;
          markdown = true;
        };
      };
    };
  };

  # Set as default editor
  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
