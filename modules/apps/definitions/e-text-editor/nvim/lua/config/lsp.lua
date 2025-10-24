-- nvim/lua/config/lsp.lua

local on_attach = function(client, bufnr)
  local opts = { noremap = true, silent = true, buffer = bufnr }
  local keymap = vim.keymap.set
  keymap("n", "gD", vim.lsp.buf.declaration, opts)
  keymap("n", "gd", vim.lsp.buf.definition, opts)
  keymap("n", "K", vim.lsp.buf.hover, opts)
  keymap("n", "gi", vim.lsp.buf.implementation, opts)
  keymap("n", "<C-k>", vim.lsp.buf.signature_help, opts)
  keymap("n", "<leader>rn", vim.lsp.buf.rename, opts)
  keymap("n", "<leader>ca", vim.lsp.buf.code_action, opts)
  keymap("n", "gr", vim.lsp.buf.references, opts)
end

require("lze").load({
  {
    "nvim-lspconfig",
    dependencies = { "cmp-nvim-lsp" }, -- <<< THIS IS THE FIX
    on_require = { "lspconfig" },
    lsp = function(plugin)
      local cfg = plugin.lsp or {}
      cfg.on_attach = on_attach
      cfg.capabilities = require("cmp_nvim_lsp").default_capabilities() -- This will now work
      vim.lsp.config(plugin.name, cfg)
      vim.lsp.enable(plugin.name)
    end,
  },

  -- Individual Language Server specs
  { "nixd", lsp = { filetypes = { "nix" } } },
  { "nil_ls", lsp = { filetypes = { "nix" } } },
  {
    "lua_ls",
    lsp = {
      filetypes = { "lua" },
      settings = {
        Lua = {
          runtime = { version = "LuaJIT" },
          diagnostics = { globals = { "vim", "nixCats", "require" } },
        },
      },
    },
  },
  { "pyright", lsp = { filetypes = { "python" } } },
  { "ruff", lsp = { filetypes = { "python" } } },
  { "bashls", lsp = { filetypes = { "sh" } } },
  { "marksman", lsp = { filetypes = { "markdown" } } },
})
