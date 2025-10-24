vim.g.mapleader = "\\"
vim.g.maplocalleader = "\\"

require("config.options")

require("config.colorscheme")
require("config.lualine")
require("nvim-web-devicons").setup({ default = true })

local lze = require("lze")

lze.load({
  {
    "nvim-treesitter",
    event = "BufReadPost",
    config = function()
      require("config.treesitter")
    end,
  },
  {
    "indent-blankline.nvim",
    event = "BufReadPost",
    config = function()
      require("ibl").setup({ scope = { enabled = true } })
    end,
  },
  {
    "which-key.nvim",
    event = "UIEnter", -- This was changed from "VeryLazy"
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
    "Comment.nvim",
    keys = { { "gc", mode = { "n", "v" } }, { "gb", mode = { "n", "v" } } },
    config = function()
      require("Comment").setup({})
    end,
  },
  {
    "nvim-cmp",
    event = "InsertEnter",
    dependencies = {
      "luasnip",
      "cmp_luasnip",
      "cmp-nvim-lsp",
      "cmp-buffer",
      "cmp-path",
    },
    config = function()
      require("config.completion")
    end,
  },
  {
    "conform.nvim",
    event = "BufWritePre",
    config = function()
      require("config.formatting")
    end,
  },
  {
    "nvim-lspconfig",
    event = "BufReadPost",
    config = function()
      require("config.lsp")
    end,
  },
  {
    "gitsigns.nvim",
    event = "BufReadPost",
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { text = "+" },
          change = { text = "~" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
        },
      })
    end,
  },
  {
    "nvim-dap",
    dependencies = { "nvim-dap-ui", "nvim-dap-virtual-text", "nvim-dap-python" },
    keys = {
      { "\\dc", mode = "n" }, { "\\ds", mode = "n" }, { "\\di", mode = "n" },
      { "\\du", mode = "n" }, { "\\db", mode = "n" }, { "\\dB", mode = "n" },
    },
    config = function()
      require("config.dap")
    end,
  },
  {
    "fzf-lua",
    cmd = { "FzfLua" },
    keys = {
      { "\\p", mode = "n" }, { "\\g", mode = "n" },
      { "\\b", mode = "n" }, { "\\h", mode = "n" },
    },
    config = function()
      require("fzf-lua").setup({
        winopts = { preview = { default = "bat" } },
      })
    end,
  },
  {
    "render-markdown.nvim",
    ft = "markdown",
    config = function()
      require("render-markdown").setup({
        html = { enabled = false },
        latex = { enabled = false },
        yaml = { enabled = false },
      })
    end,
  },
})

require("config.terminal")
require("config.keymaps")
