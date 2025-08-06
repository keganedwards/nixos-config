# modules/home-manager/apps/definitions/e-text-editor/nvf-config.nix
{
  pkgs,
  inputs,
  ...
}:
# Only arguments it truly needs
let
  nvfModuleStyleOptions = {
    config.vim = {
      options = {
        expandtab = true;
        tabstop = 4;
        shiftwidth = 4;
        softtabstop = 4;
        relativenumber = true;

        # --- Add these lines for setting the Neovim title ---
        title = true; # Equivalent to vim.opt.title = true
        titlestring = "%t"; # Sets title to the filename tail.
        # You can use other formats too, e.g.:
        # titlestring = "%F"; # Full path
        # titlestring = "nvim: %t"; # Prefix with "nvim: "
        # titlestring = "%t%s%m%r"; # Filename, modified status, readonly status
        # --- End of title setting lines ---
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
          extensions.render-markdown-nvim.enable = true;
        };
        python = {
          enable = true;
          dap = {
            enable = true;
            package = pkgs.python3.withPackages (ps: [ps.debugpy]);
          };
        };
      };
      autocomplete = {
        "nvim-cmp" = {
          enable = true;
          sources = {
            nvim_lsp = "[LSP]";
            buffer = "[Buffer]";
            path = "[Path]";
            nvim_lua = "[Lua]";
          };
        };
      };
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
          };
        };
      };
      extraPackages = [pkgs.fzf pkgs.alejandra pkgs.black pkgs.nodePackages.prettier pkgs.stylua pkgs.csharpier pkgs.wl-clipboard];
      extraPlugins = with pkgs.vimPlugins; {
        cmp-nvim-lsp = {package = cmp-nvim-lsp;};
        cmp-buffer = {package = cmp-buffer;};
        cmp-path = {package = cmp-path;};
        cmp-nvim-lua = {package = cmp-nvim-lua;};
        cmp_luasnip = {package = cmp_luasnip;};
        friendly-snippets = {package = friendly-snippets;};
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
    };
  };
in {
  inherit nvfModuleStyleOptions; # If needed elsewhere, otherwise can be local to this file's let
  customNvfNeovimDerivation = inputs.nvf.lib.neovimConfiguration {
    # Changed name for clarity
    inherit pkgs;
    modules = [nvfModuleStyleOptions]; # This passes the options including the new title settings
  };
}
