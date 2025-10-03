{pkgs, ...}: {
  vim = {
    options = {
      expandtab = true;
      tabstop = 4;
      shiftwidth = 4;
      softtabstop = 4;
      relativenumber = true;
      title = true;
      titlestring = "%t";
    };

    maps = {
      normal."<C-t>" = {
        action = "lua require('fzf-lua').files()<CR>";
        silent = true;
        desc = "FzfLua Files";
      };
    };

    spellcheck.enable = true;
    globals.mapleader = "\\";
    clipboard = {
      registers = "unnamedplus";
      enable = true;
    };
    debugger.nvim-dap = {
      enable = true;
      ui.enable = true;
    };
    languages = {
      enableTreesitter = true;
      enableDAP = true;
      java.enable = true;
      ts.enable = true;
      csharp = {
        enable = true;
        lsp.enable = true;
      };
      r = {
        enable = true;
        lsp.enable = true;
      };
      nix = {
        enable = true;
        lsp.enable = true;
      };
      markdown = {
        enable = true;
        extensions.render-markdown-nvim = {
          enable = true;
          setupOpts = {
            html.enabled = false;
            latex.enabled = false;
            yaml.enabled = false;
          };
        };
      };
      python = {
        enable = true;
        dap = {
          enable = true;
          package = pkgs.python3.withPackages (ps: [ps.debugpy]);
        };
      };
      bash.enable = true;
    };
    autocomplete."nvim-cmp".enable = true;
    statusline.lualine.enable = true;
    fzf-lua.enable = true;
    git.enable = true;
    comments.comment-nvim.enable = true;
    autopairs.nvim-autopairs.enable = true;
    visuals.nvim-web-devicons.enable = true;
    formatter.conform-nvim = {
      enable = true;
      setupOpts = {
        format_on_save = {
          lsp_format = "fallback";
          timeout_ms = 1000;
        };
        formatters_by_ft = {
          nix = ["alejandra"];
          python = ["black"];
          typescript = ["prettier"];
          javascript = ["prettier"];
          json = ["prettier"];
          yaml = ["prettier"];
          markdown = ["prettier"];
          lua = ["stylua"];
          csharp = ["csharpier"];
          sh = ["shfmt"];
          bash = ["shfmt"];
        };
      };
    };
    snippets.luasnip = {
      enable = true;
      loaders = ''require('luasnip.loaders.from_vscode').lazy_load() require('luasnip.loaders.from_snipmate').lazy_load() '';
    };
    binds.whichKey = {
      enable = true;
      setupOpts.preset = "modern";
    };
    visuals.indent-blankline = {
      enable = true;
      setupOpts.scope.enabled = true;
    };
    extraPlugins = with pkgs.vimPlugins; {
      cmp-nvim-lsp = {package = cmp-nvim-lsp;};
      cmp-buffer = {package = cmp-buffer;};
      cmp-path = {package = cmp-path;};
      cmp-nvim-lua = {package = cmp-nvim-lua;};
      cmp_luasnip = {package = cmp_luasnip;};
      friendly-snippets = {package = friendly-snippets;};
    };
    extraPackages = [
      pkgs.fzf
      pkgs.alejandra
      pkgs.black
      pkgs.nodePackages.prettier
      pkgs.stylua
      pkgs.shfmt
      pkgs.wl-clipboard
      pkgs.gcc
      pkgs.tree-sitter
      pkgs.dotnet-sdk
      pkgs.csharpier
      pkgs.luajitPackages.jsregexp
    ];
  };
}
