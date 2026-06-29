require("lazyload").on_vim_enter(function()
  vim.pack.add({
    "https://github.com/lewis6991/async.nvim",
    "https://github.com/theprimeagen/refactoring.nvim",
  })
end)
