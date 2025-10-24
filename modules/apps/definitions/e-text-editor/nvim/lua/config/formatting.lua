require("conform").setup({
  formatters_by_ft = {
    python = { "black", "ruff" },
    bash = { "shfmt" },
    nix = { "alejandra" },
    lua = { "stylua" },
  },
  format_on_save = {
    timeout_ms = 500,
    lsp_fallback = true,
  },
})
