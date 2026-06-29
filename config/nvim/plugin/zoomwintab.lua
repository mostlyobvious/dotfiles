require("lazyload").on_vim_enter(function()
  vim.pack.add({
    "https://github.com/troydm/zoomwintab.vim",
  })

  vim.keymap.set("n", "<Leader><Leader>", "<Cmd>ZoomWinTabToggle<CR>", { desc = "Zoom window" })
end)
