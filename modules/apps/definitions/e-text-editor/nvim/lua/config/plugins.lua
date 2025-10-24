-- nvim/lua/config/plugins.lua

-- Immediately load the colorscheme and UI components for visual consistency
require("config.colorscheme")
require("config.lualine")
require("nvim-web-devicons").setup({ default = true })

local lze = require("lze")

lze.load({
	-- Treesitter
	{
		"nvim-treesitter",
		event = "BufReadPost",
		config = function()
			require("config.treesitter")
		end,
	},
	-- Indent blankline
	{
		"indent-blankline.nvim",
		event = "BufReadPost",
		config = function()
			require("ibl").setup({ scope = { enabled = true } })
		end,
	},
	-- Which-key
	{
		"which-key.nvim",
		event = "UIEnter",
		config = function()
			require("which-key").setup({ preset = "modern" })
		end,
	},
	{
		"nvim-autopairs",
		event = "InsertEnter",
		config = function()
			require("config.autopairs")
		end,
	},
	{
		"nvim-cmp",
		event = "InsertEnter",
		dependencies = { "luasnip", "cmp_luasnip", "cmp-buffer", "cmp-path" },
		config = function()
			require("config.completion")
		end,
	},
	{
		"Comment.nvim",
		keys = { { "gc", mode = { "n", "v" } }, { "gb", mode = { "n", "v" } } },
		config = function()
			require("Comment").setup({})
		end,
	},
	{
		"gitsigns.nvim",
		event = "BufReadPost",
		config = function()
			require("gitsigns").setup()
		end,
	},
	{
		"nvim-dap",
		dependencies = { "nvim-dap-ui", "nvim-dap-virtual-text", "nvim-dap-python" },
		config = function()
			require("config.dap")
		end,
	},
	{
		"fzf-lua",
		cmd = { "FzfLua" },
		config = function()
			require("fzf-lua").setup({ winopts = { preview = { default = "bat" } } })
		end,
	},
	{
		"render-markdown.nvim",
		ft = "markdown",
		config = function()
			require("render-markdown").setup({ html = { enabled = false } })
		end,
	},

	-- ===================================================================
	-- CORRECTED NVIM-LINT CONFIGURATION
	-- ===================================================================
	{
		"mfussenegger/nvim-lint",
		-- This is the main fix: Trigger loading only when a 'nix' file is opened.
		ft = "nix",
		config = function()
			-- This message will appear ONLY when the plugin loads successfully.
			print("✅ nvim-lint has been loaded for a Nix file.")

			local lint = require("lint")
			lint.linters_by_ft = {
				nix = { "deadnix", "statix" },
			}

			-- Group autocommands to prevent duplication
			local lint_augroup = vim.api.nvim_create_augroup("nvim-lint-autocmds", { clear = true })

			vim.api.nvim_create_autocmd({ "BufWritePost" }, {
				group = lint_augroup,
				callback = function()
					print("BufWritePost triggered: trying to lint.")
					lint.try_lint()
				end,
			})
		end,
	},
	-- ===================================================================
})
