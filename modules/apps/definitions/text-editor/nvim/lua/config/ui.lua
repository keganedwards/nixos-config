-- Lualine
require("lualine").setup({
  options = {
    theme = "catppuccin",
    component_separators = { left = "", right = "" },
    section_separators = { left = "", right = "" },
  },
})

-- Indent Blankline
require("ibl").setup({
  scope = { enabled = true },
})

-- Web devicons
require("nvim-web-devicons").setup({
  default = true,
})
