local keymap = vim.keymap.set

keymap("n", "\\t", "<cmd>FzfLua files<CR>", { desc = "Find files", silent = true })
keymap("n", "\\g", "<cmd>FzfLua live_grep<CR>", { desc = "Grep (live)" })
keymap("n", "\\o", "<cmd>FzfLua buffers<CR>", { desc = "Open buffers" })
keymap("n", "\\h", "<cmd>FzfLua help_tags<CR>", { desc = "Help tags" })

keymap("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
keymap("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
keymap("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
keymap("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

keymap("v", "\\k", ":m '<-2<CR>gv=gv", { desc = "Move line up" })
keymap("v", "\\j", ":m '>+1<CR>gv=gv", { desc = "Move line down" })

if nixCats('debug') then
  keymap("n", "\\c", require("dap").continue, { desc = "Debug: Continue" })
  keymap("n", "\\s", require("dap").step_over, { desc = "Debug: Step Over" })
  keymap("n", "\\i", require("dap").step_into, { desc = "Debug: Step Into" })
  keymap("n", "\\u", require("dap").step_out, { desc = "Debug: Step Out" })

  keymap("n", "\\b", require("dap").toggle_breakpoint, { desc = "Debug: Toggle Breakpoint" })
  keymap("n", "\\B", function()
    require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
  end, { desc = "Debug: Set Conditional Breakpoint" })
end
