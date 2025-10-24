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
          tree-sitter
          ripgrep
          fd
          gcc
          bat
        ];
        bash = with pkgs; [
          nodejs
          nodePackages.bash-language-server
          shfmt
        ];
        lua = with pkgs; [
          lua-language-server
          stylua
        ];
        markdown = with pkgs; [
          marksman
        ];
        nix = with pkgs; [
          statix
          deadnix
          alejandra
          nixd
        ];
        python = with pkgs; [
          pyright
          ruff
          black
        ];
      };

      startupPlugins = {
        general = with pkgs.vimPlugins; [
          plenary-nvim
          nvim-web-devicons
          lze
          catppuccin-nvim
          lualine-nvim
          indent-blankline-nvim
          which-key-nvim
          nvim-treesitter
          nvim-treesitter-parsers.vim
          nvim-treesitter-parsers.vimdoc
          nvim-treesitter-textobjects
          nvim-autopairs
          comment-nvim
          vim-surround
          nvim-lspconfig
          nvim-cmp
          cmp-nvim-lsp
          cmp-buffer
          cmp-path
          cmp-cmdline
          luasnip
          cmp_luasnip
          friendly-snippets
          conform-nvim
          fzf-lua
          nvim-dap
          nvim-dap-ui
          nvim-dap-virtual-text
        ];
        git = with pkgs.vimPlugins; [
          gitsigns-nvim
          vim-fugitive
        ];
        bash = with pkgs.vimPlugins; [
          nvim-treesitter-parsers.bash
        ];
        lua = with pkgs.vimPlugins; [
          nvim-treesitter-parsers.lua
        ];
        json = with pkgs.vimPlugins; [
          nvim-treesitter-parsers.json
        ];
        markdown = with pkgs.vimPlugins; [
          render-markdown-nvim
          nvim-treesitter-parsers.markdown
          nvim-treesitter-parsers.markdown_inline
        ];
        nix = with pkgs.vimPlugins; [
          nvim-treesitter-parsers.nix
        ];
        python = with pkgs.vimPlugins; [
          nvim-dap-python
          nvim-treesitter-parsers.python
        ];
        yaml = with pkgs.vimPlugins; [
          nvim-treesitter-parsers.yaml
        ];
        terminal = with pkgs.vimPlugins; [];
      };

      python3.libraries = {
        python = ps: with ps; [debugpy];
      };
    };

    packageDefinitions.replace = {
      nvim = _: {
        settings = {
          wrapRc = true;
          aliases = ["vi" "vim"];
        };
        categories = {
          general = true;
          git = true;
          bash = true;
          lua = true;
          json = true;
          markdown = true;
          nix = true;
          python = true;
          yaml = true;
          terminal = true;
        };
      };
    };
  };

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
