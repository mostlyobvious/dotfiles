require("lazyload").on_vim_enter(function()
  vim.pack.add({
    "https://github.com/MeanderingProgrammer/render-markdown.nvim",
  })

  require("render-markdown").setup({
    completions = { blink = { enabled = true } },
  })
end)
