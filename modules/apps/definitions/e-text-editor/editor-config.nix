{pkgs, ...}: {
  programs.nvf = {
    enable = true;
    settings = {
      vim = {
    luaConfigPre = ''
      vim.deprecate = function() end
    '';

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
enable = true;
registers = "unnamedplus";
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
            format.enable = true;
            extraDiagnostics.enable = true;
            treesitter.enable = true;
          };
          markdown = {
            enable = true;
            extensions.render-markdown-nvim.enable = true;
          };
          python = {
            enable = true;
            format.enable = true;
            dap = {
              enable = true;
              package = pkgs.python3.withPackages (ps: [ps.debugpy]);
            };
          };
          bash = {
            enable = true;
            format.enable = true;
          };
        };

        autocomplete."nvim-cmp".enable = true;
        statusline.lualine.enable = true;
        fzf-lua.enable = true;
        git.enable = true;
        comments.comment-nvim.enable = true;
        autopairs.nvim-autopairs.enable = true;
        visuals.nvim-web-devicons.enable = true;
        snippets.luasnip.enable = true;

        binds.whichKey = {
          enable = true;
          setupOpts.preset = "modern";
        };

        visuals.indent-blankline = {
          enable = true;
          setupOpts.scope.enabled = true;
        };
      };
    };
  };
}
