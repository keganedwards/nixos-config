-- nvim/lua/config/formatting.lua

require("conform").setup({

	formatters_by_ft = {
		python = { "black", "ruff" },
		bash = { "shfmt" },
		nix = { "alejandra" },
		lua = { "stylua" },
	},

	format_on_save = {
		timeout_ms = 2000,
		lsp_fallback = true,
	},
})
