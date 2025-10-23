-- nvim/lua/config/fzf.lua
require("fzf-lua").setup({
  winopts = {
    preview = {
      default = "bat",
    },
  },
})
