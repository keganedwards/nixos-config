-- nvim/lua/config/dap.lua
local dap = require("dap")
local dapui = require("dapui")

dapui.setup()

-- Python
require("dap-python").setup()

-- DAP UI integration
dap.listeners.after.event_initialized["dapui_config"] = function()
	dapui.open()
end
dap.listeners.before.event_terminated["dapui_config"] = function()
	dapui.close()
end
dap.listeners.before.event_exited["dapui_config"] = function()
	dapui.close()
end

-- Virtual text
require("nvim-dap-virtual-text").setup()

-- Keymaps (using leader+d prefix to avoid conflicts)
local keymap = vim.keymap.set
keymap("n", "<leader>dc", dap.continue, { desc = "Debug: Continue" })
keymap("n", "<leader>ds", dap.step_over, { desc = "Debug: Step Over" })
keymap("n", "<leader>di", dap.step_into, { desc = "Debug: Step Into" })
keymap("n", "<leader>du", dap.step_out, { desc = "Debug: Step Out" })
keymap("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug: Toggle Breakpoint" })
keymap("n", "<leader>dB", function()
	dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
end, { desc = "Debug: Set Conditional Breakpoint" })
