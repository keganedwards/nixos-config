local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Indentation
opt.expandtab = true
opt.shiftwidth = 2
opt.tabstop = 2
opt.softtabstop = 2
opt.smartindent = true

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = false
opt.incsearch = true

-- UI
opt.termguicolors = true
opt.signcolumn = "yes"
opt.wrap = false
opt.scrolloff = 8
opt.sidescrolloff = 8

-- System
opt.clipboard = "unnamedplus"
opt.updatetime = 50
opt.timeoutlen = 300

-- Spell
opt.spell = true
opt.spelllang = { "en_us" }

-- Splits
opt.splitbelow = true
opt.splitright = true
