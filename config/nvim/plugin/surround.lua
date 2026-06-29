require("lazyload").on_vim_enter(function()
  vim.pack.add({
    "https://github.com/kylechui/nvim-surround",
  })

  require("nvim-surround").setup({})
end)
