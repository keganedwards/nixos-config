-- nvim/lua/config/keymaps.lua
local keymap = vim.keymap.set

-- FZF keybindings (direct leader mappings, no nesting)
keymap("n", "<leader>p", "<cmd>FzfLua files<CR>", { desc = "Find files", silent = true })
keymap("n", "<leader>g", "<cmd>FzfLua live_grep<CR>", { desc = "Grep (live)" })
keymap("n", "<leader>b", "<cmd>FzfLua buffers<CR>", { desc = "Open buffers" })
keymap("n", "<leader>h", "<cmd>FzfLua help_tags<CR>", { desc = "Help tags" })

-- Tab navigation (simplified - just numbers and close)
keymap("n", "<leader>1", "<cmd>tabn 1<CR>", { desc = "Go to tab 1" })
keymap("n", "<leader>2", "<cmd>tabn 2<CR>", { desc = "Go to tab 2" })
keymap("n", "<leader>3", "<cmd>tabn 3<CR>", { desc = "Go to tab 3" })
keymap("n", "<leader>4", "<cmd>tabn 4<CR>", { desc = "Go to tab 4" })
keymap("n", "<leader>5", "<cmd>tabn 5<CR>", { desc = "Go to tab 5" })
keymap("n", "<leader>6", "<cmd>tabn 6<CR>", { desc = "Go to tab 6" })
keymap("n", "<leader>7", "<cmd>tabn 7<CR>", { desc = "Go to tab 7" })
keymap("n", "<leader>8", "<cmd>tabn 8<CR>", { desc = "Go to tab 8" })
keymap("n", "<leader>9", "<cmd>tabn 9<CR>", { desc = "Go to tab 9" })
keymap("n", "<leader>x", "<cmd>tabclose<CR>", { desc = "Close tab" })

-- Quick tab switching
keymap("n", "<Tab>", "<cmd>tabnext<CR>", { desc = "Next tab" })
keymap("n", "<S-Tab>", "<cmd>tabprevious<CR>", { desc = "Previous tab" })

-- Window navigation
keymap("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
keymap("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
keymap("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
keymap("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Visual mode line movement
keymap("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
keymap("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })

-- Better paste
keymap("v", "p", '"_dP', { desc = "Paste without yanking" })

-- Stay in indent mode
keymap("v", "<", "<gv", { desc = "Indent left" })
keymap("v", ">", ">gv", { desc = "Indent right" })

-- Terminal shortcuts (flattened)
keymap("n", "<leader>t", "<cmd>tabnew +terminal<CR>", { desc = "New terminal tab" })
keymap("n", "<leader>v", "<cmd>vsplit +terminal<CR>", { desc = "Terminal vsplit" })
keymap("n", "<leader>s", "<cmd>split +terminal<CR>", { desc = "Terminal split" })
-- <leader>T is defined in terminal.lua for "Open terminal here"
