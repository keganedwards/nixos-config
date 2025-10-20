-- Check if we're in nixCats
local nixCats = require('nixCats')

-- Setup catppuccin
if nixCats('theme') then
  require("catppuccin").setup({
    flavour = "mocha",
  })
  vim.cmd.colorscheme("catppuccin")
end

-- Setup lualine
if nixCats('ui') then
  require('lualine').setup({
    options = {
      theme = 'catppuccin'
    }
  })
  
  -- Which-key
  require('which-key').setup()
  
  -- Indent blankline
  require('ibl').setup()
end

-- Setup editor plugins
if nixCats('editor') then
  -- Autopairs
  require('nvim-autopairs').setup()
  
  -- Comment
  require('Comment').setup()
  
  -- Gitsigns
  require('gitsigns').setup()
  
  -- Treesitter
  require('nvim-treesitter.configs').setup({
    highlight = { enable = true },
    indent = { enable = true },
  })
end

-- Setup FzfLua
if nixCats('navigation') then
  require('fzf-lua').setup({})
end
