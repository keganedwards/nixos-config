require("conform").setup({
  formatters_by_ft = {
    python = { "black", "ruff" },
    javascript = { "prettierd" },
    typescript = { "prettierd" },
    bash = { "shfmt" },
    nix = { "alejandra" },
  },
  format_on_save = {
    timeout_ms = 500,
    lsp_fallback = true,
  },
})
