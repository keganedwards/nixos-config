local keymap = vim.keymap.set

-- File navigation with FzfLua
keymap("n", "<C-t>", "<cmd>FzfLua files<CR>", { desc = "Find files", silent = true })
keymap("n", "<leader>fg", "<cmd>FzfLua live_grep<CR>", { desc = "Live grep" })
keymap("n", "<leader>fb", "<cmd>FzfLua buffers<CR>", { desc = "Find buffers" })
keymap("n", "<leader>fh", "<cmd>FzfLua help_tags<CR>", { desc = "Help tags" })

-- Better window navigation
keymap("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
keymap("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
keymap("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
keymap("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

-- Move lines
keymap("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move line down" })
keymap("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move line up" })

-- DAP
if nixCats('debug') then
  keymap("n", "<F5>", require("dap").continue, { desc = "Debug: Continue" })
  keymap("n", "<F10>", require("dap").step_over, { desc = "Debug: Step Over" })
  keymap("n", "<F11>", require("dap").step_into, { desc = "Debug: Step Into" })
  keymap("n", "<F12>", require("dap").step_out, { desc = "Debug: Step Out" })
  keymap("n", "<leader>b", require("dap").toggle_breakpoint, { desc = "Debug: Toggle Breakpoint" })
  keymap("n", "<leader>B", function()
    require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
  end, { desc = "Debug: Set Conditional Breakpoint" })
end
