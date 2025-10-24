
local M = {}

-- Terminal settings
vim.api.nvim_create_autocmd("TermOpen", {
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = "no"
    vim.cmd("startinsert")

    if vim.g.neovide then
      vim.opt_local.termguicolors = true
    end
  end,
})

-- --- START: ERGONOMIC MAPPINGS ---
-- The standard way to exit terminal mode
vim.keymap.set('t', '<Esc>', '<C-\\><C-n>', { desc = 'Terminal: Exit to normal mode' })

-- A more ergonomic way to exit terminal mode, keeping hands on the home row
vim.keymap.set('t', 'jk', '<C-\\><C-n>', { desc = 'Terminal: Exit to normal mode (ergonomic)' })
-- --- END: ERGONOMIC MAPPINGS ---


-- Terminal mode navigation
vim.keymap.set("t", "<C-\\><C-n>", "<C-\\><C-n>", { desc = "Exit terminal mode" })
vim.keymap.set("t", "<C-w>h", "<C-\\><C-n><C-w>h", { desc = "Go to left window" })
vim.keymap.set("t", "<C-w>j", "<C-\\><C-n><C-w>j", { desc = "Go to lower window" })
vim.keymap.set("t", "<C-w>k", "<C-\\><C-n><C-w>k", { desc = "Go to upper window" })
vim.keymap.set("t", "<C-w>l", "<C-\\><C-n><C-w>l", { desc = "Go to right window" })

-- Function to convert current buffer to terminal or open in new tab
local function open_terminal_here()
  if vim.bo.buftype == "terminal" then
    return
  end

  if vim.bo.modified then
    vim.cmd("tabnew")
    vim.cmd("terminal")
  else
    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    local has_content = false
    for _, line in ipairs(lines) do
      if line ~= "" then
        has_content = true
        break
      end
    end

    if has_content then
      vim.cmd("tabnew")
      vim.cmd("terminal")
    else
      vim.cmd("terminal")
    end
  end
end

-- Keybinding to open terminal at current location
vim.keymap.set("n", "<leader>T", open_terminal_here, { desc = "Open terminal here" })

-- Neovide specific settings
if vim.g.neovide then
  vim.g.neovide_input_use_logo = 1
  vim.api.nvim_set_keymap('', '<D-v>', '+p<CR>', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('!', '<D-v>', '<C-R>+', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('t', '<D-v>', '<C-R>+', { noremap = true, silent = true })
  vim.api.nvim_set_keymap('v', '<D-v>', '<C-R>+', { noremap = true, silent = true })
  vim.keymap.set('t', '<C-S-v>', '<C-\\><C-n>"+pi', { silent = true })
end

return M
