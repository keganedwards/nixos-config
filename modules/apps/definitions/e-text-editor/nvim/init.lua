-- nvim/init.lua

-- Set leader keys
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Load base editor options first
require("config.options")

-- Register the lzextras lsp handler for filetype-based lazy loading
-- This is a crucial step from the template
require("lze").register_handlers(require("lzextras").lsp)

-- Load all other configuration modules
require("config.plugins") -- General plugins
require("config.lsp") -- All LSP configurations
require("config.formatting") -- All formatter configurations
require("config.keymaps") -- Your keymaps
require("config.terminal") -- Your terminal setup
