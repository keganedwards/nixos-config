-- nvim/lua/config/terminal.lua
local M = {}

-- Terminal settings
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.cmd("startinsert")
  end,
})

-- Keymaps for terminal mode
vim.keymap.set("t", "<C-\\><C-n>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
vim.keymap.set("t", "<C-h>", "<C-\\><C-n><C-w>h", { desc = "Go to left window" })
vim.keymap.set("t", "<C-j>", "<C-\\><C-n><C-w>j", { desc = "Go to lower window" })
vim.keymap.set("t", "<C-k>", "<C-\\><C-n><C-w>k", { desc = "Go to upper window" })
vim.keymap.set("t", "<C-l>", "<C-\\><C-n><C-w>l", { desc = "Go to right window" })

-- Tab navigation
vim.keymap.set("n", "<leader>tn", "<cmd>tabnew<CR>", { desc = "New tab" })
vim.keymap.set("n", "<leader>tc", "<cmd>tabclose<CR>", { desc = "Close tab" })
vim.keymap.set("n", "<leader>to", "<cmd>tabonly<CR>", { desc = "Close other tabs" })
vim.keymap.set("n", "<leader>th", "<cmd>tabprevious<CR>", { desc = "Previous tab" })
vim.keymap.set("n", "<leader>tl", "<cmd>tabnext<CR>", { desc = "Next tab" })
vim.keymap.set("n", "<leader>tt", "<cmd>tabnew +terminal<CR>", { desc = "New terminal tab" })

-- Quick terminal toggle
vim.keymap.set("n", "<leader>tv", "<cmd>vsplit +terminal<CR>", { desc = "Terminal vsplit" })
vim.keymap.set("n", "<leader>ts", "<cmd>split +terminal<CR>", { desc = "Terminal split" })

-- Open terminal at current file's directory
vim.keymap.set("n", "<leader>td", function()
  local dir = vim.fn.expand("%:p:h")
  vim.cmd("tabnew")
  vim.cmd("lcd " .. dir)
  vim.cmd("terminal")
end, { desc = "Terminal in file dir" })

-- Don't start server here - neovide handles it with --listen flag

return M
