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
        general = with pkgs; [tree-sitter ripgrep fd gcc bat];
        bash = with pkgs; [nodejs nodePackages.bash-language-server shfmt];
        lua = with pkgs; [lua-language-server stylua];
        markdown = with pkgs; [marksman];
        nix = with pkgs; [statix deadnix alejandra nixd nil];
        python = with pkgs; [pyright ruff black];
      };

      startupPlugins = {
        general = with pkgs.vimPlugins; [
          conform-nvim
          plenary-nvim
          lze
          lzextras
          cmp-nvim-lsp
          catppuccin-nvim
          lualine-nvim
          nvim-web-devicons
          nvim-lint # <-- MOVE NVIM-LINT HERE
        ];
      };

      # Plugins managed by the lazy-loader (`lze`).
      optionalPlugins = {
        general = with pkgs.vimPlugins; [
          indent-blankline-nvim
          which-key-nvim
          # nvim-lint <-- REMOVE IT FROM THIS LIST
          nvim-treesitter
          nvim-treesitter-parsers.vim
          nvim-treesitter-parsers.vimdoc
          nvim-treesitter-textobjects
          nvim-autopairs
          comment-nvim
          vim-surround
          nvim-lspconfig
          nvim-cmp
          cmp-buffer
          cmp-path
          cmp-cmdline
          luasnip
          cmp_luasnip
          friendly-snippets
          fzf-lua
          nvim-dap
          nvim-dap-ui
          nvim-dap-virtual-text
        ];
        git = with pkgs.vimPlugins; [gitsigns-nvim vim-fugitive];
        bash = with pkgs.vimPlugins; [nvim-treesitter-parsers.bash];
        lua = with pkgs.vimPlugins; [nvim-treesitter-parsers.lua];
        json = with pkgs.vimPlugins; [nvim-treesitter-parsers.json];
        markdown = with pkgs.vimPlugins; [
          render-markdown-nvim
          nvim-treesitter-parsers.markdown
          nvim-treesitter-parsers.markdown_inline
        ];
        nix = with pkgs.vimPlugins; [nvim-treesitter-parsers.nix];
        python = with pkgs.vimPlugins; [
          nvim-dap-python
          nvim-treesitter-parsers.python
        ];
        yaml = with pkgs.vimPlugins; [nvim-treesitter-parsers.yaml];
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
        };
      };
    };
  };

  environment.variables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
