-- Setup completion capabilities
local capabilities = require("cmp_nvim_lsp").default_capabilities()

-- Common on_attach
local on_attach = function(client, bufnr)
  local opts = { noremap = true, silent = true, buffer = bufnr }

  -- Keybindings
  vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)
  vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
  vim.keymap.set("n", "K", vim.lsp.buf.hover, opts)
  vim.keymap.set("n", "gi", vim.lsp.buf.implementation, opts)
  vim.keymap.set("n", "<C-k>", vim.lsp.buf.signature_help, opts)
  vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, opts)
  vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, opts)
  vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
  vim.keymap.set("n", "<leader>f", function()
    vim.lsp.buf.format({ async = true })
  end, opts)
end

-- Configure LSP servers using the new vim.lsp.config approach
local servers = {
  -- Nix
  nixd = {},
  nil_ls = {},

  -- Lua
  lua_ls = {
    settings = {
      Lua = {
        runtime = { version = "LuaJIT" },
        diagnostics = {
          globals = { "vim", "nixCats" },
        },
        workspace = {
          library = vim.api.nvim_get_runtime_file("", true),
          checkThirdParty = false,
        },
        telemetry = { enable = false },
      },
    },
  },

  -- Python
  pyright = {},
  ruff = {},

  -- TypeScript/JavaScript
  ts_ls = {},

  -- C#
  omnisharp = {
    cmd = { "omnisharp" },
  },

  -- Java
  jdtls = {},

  -- R
  r_language_server = {},

  -- Bash
  bashls = {},

  -- Markdown
  marksman = {},

  -- LaTeX
  texlab = {},
}

-- Setup all servers using new approach
for server, config in pairs(servers) do
  config.on_attach = on_attach
  config.capabilities = capabilities

  -- Use the new vim.lsp.config API
  vim.lsp.config[server] = config
  vim.lsp.enable(server)
end
