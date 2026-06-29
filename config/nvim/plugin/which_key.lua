vim.o.timeout = true
vim.o.timeoutlen = 300

require("lazyload").on_vim_enter(function()
  vim.pack.add({
    "https://github.com/folke/which-key.nvim",
  })

  require("which-key").setup()
end)
