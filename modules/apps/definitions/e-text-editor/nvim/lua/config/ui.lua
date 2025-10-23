-- Lualine - loaded at startup
require("lualine").setup({
  options = {
    theme = "catppuccin",
    component_separators = { left = "", right = "" },
    section_separators = { left = "", right = "" },
  },
})

-- Web devicons
require("nvim-web-devicons").setup({
  default = true,
})
