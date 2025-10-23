-- nvim/init.lua
-- Set leader keys
vim.g.mapleader = "\\"
vim.g.maplocalleader = "\\"

-- Basic options
require("config.options")

-- Always load theme and lualine immediately for visual consistency
if nixCats('general') then
  require("config.colorscheme")
  require("lualine").setup({
    options = {
      theme = "catppuccin",
      component_separators = { left = "", right = "" },
      section_separators = { left = "", right = "" },
    },
  })
end

-- Setup lze for lazy loading
local lze = require("lze")

if nixCats('general') then
  lze.load({
    -- Treesitter
    {
      "nvim-treesitter",
      event = "BufReadPost",
      load = function()
        require("config.treesitter")
      end,
    },
    
    -- Indent blankline
    {
      "indent-blankline.nvim",
      event = "BufReadPost",
      load = function()
        require("ibl").setup({ scope = { enabled = true } })
      end,
    },
    
    -- Which-key
    {
      "which-key.nvim",
      event = "UIEnter",
      load = function()
        require("which-key").setup({ preset = "modern" })
      end,
    },
    
    -- Completion
    {
      "nvim-cmp",
      event = "InsertEnter",
      load = function()
        require("config.completion")
      end,
    },
    
    -- FZF with simplified keys
    {
      "fzf-lua",
      cmd = { "FzfLua" },
      keys = {
        { "\\p", mode = "n" },
        { "\\g", mode = "n" },
        { "\\b", mode = "n" },
        { "\\h", mode = "n" },
      },
      load = function()
        require("config.fzf")
      end,
    },
    
    -- Autopairs
    {
      "nvim-autopairs",
      event = "InsertEnter",
      load = function()
        require("config.autopairs")
      end,
    },
    
    -- Comment
    {
      "Comment.nvim",
      keys = {
        { "gc", mode = { "n", "v" } },
        { "gb", mode = { "n", "v" } },
      },
      load = function()
        require("config.comment")
      end,
    },
    
    -- Formatting
    {
      "conform.nvim",
      event = "BufWritePre",
      load = function()
        require("config.formatting")
      end,
    },
  })
end

if nixCats('lsp') then
  lze.load({
    {
      "nvim-lspconfig",
      event = "BufReadPost",
      load = function()
        require("config.lsp")
      end,
    },
  })
end

if nixCats('git') then
  lze.load({
    {
      "gitsigns.nvim",
      event = "BufReadPost",
      load = function()
        require("config.git")
      end,
    },
  })
end

if nixCats('debug') then
  lze.load({
    {
      "nvim-dap",
      keys = {
        { "\\dc", mode = "n" },
        { "\\ds", mode = "n" },
        { "\\di", mode = "n" },
        { "\\du", mode = "n" },
        { "\\db", mode = "n" },
        { "\\dB", mode = "n" },
      },
      load = function()
        require("config.dap")
      end,
    },
  })
end

if nixCats('markdown') then
  lze.load({
    {
      "render-markdown.nvim",
      ft = "markdown",
      load = function()
        require("config.markdown")
      end,
    },
  })
end

-- Terminal config (always load)
if nixCats('general') then
  require("config.terminal")
end

-- Keymaps
require("config.keymaps")
