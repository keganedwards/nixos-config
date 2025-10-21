-- Set leader keys
vim.g.mapleader = "\\"
vim.g.maplocalleader = "\\"

-- Basic options
require("config.options")

-- Plugin configurations (only load if category is enabled)
if nixCats('general') then
  require("config.colorscheme")
  require("config.treesitter")
  require("config.ui")
  require("config.completion")
  require("config.fzf")
  require("config.autopairs")
  require("config.comment")
  require("config.which-key")
  require("config.formatting")
end

if nixCats('lsp') then
  require("config.lsp")
end

if nixCats('git') then
  require("config.git")
end

if nixCats('debug') then
  require("config.dap")
end

if nixCats('markdown') then
  require("config.markdown")
end

-- Keymaps should be loaded last
require("config.keymaps")


-- Add to init.lua after other requires
if nixCats('general') then
  -- ... existing requires ...
  require("config.terminal")
end
