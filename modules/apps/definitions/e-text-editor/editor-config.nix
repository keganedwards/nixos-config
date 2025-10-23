{nixCats, ...}: let
  inherit (nixCats) utils;
in {
  nixCats = {
    enable = true;

    addOverlays = [
      (utils.standardPluginOverlay {})
    ];

    packageNames = ["nvim"];
    luaPath = "${./.}/nvim";

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
          nil
          nixd
          lua-language-server
          pyright
          ruff
          black
          nodePackages.typescript-language-server
          nodePackages.eslint
          prettierd
          omnisharp-roslyn
          jdt-language-server
          rPackages.languageserver
          nodePackages.bash-language-server
          shfmt
          marksman
          texlab
        ];
      };

      startupPlugins = {
        general = with pkgs.vimPlugins; [
          # Core
          plenary-nvim
          nvim-web-devicons

          # Lazy loader
          lze

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
        # Empty - all plugins in startupPlugins for lze to manage
      };

      sharedLibraries = {
        general = with pkgs; [];
      };

      python3.libraries = {
        debug = ps: with ps; [debugpy];
      };

      extraLuaPackages = {};
      environmentVariables = {
        general = {};
      };
      extraWrapperArgs = {};
    };

    packageDefinitions.replace = {
      nvim = _: {
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

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
