require("lazyload").on_vim_enter(function()
  vim.pack.add({
    "https://github.com/stevearc/oil.nvim",
  })

  local oil = require("oil")

  oil.setup({
    default_file_explorer = true,
    skip_confirm_for_simple_edits = true,
    show_hidden = true,
  })

  vim.keymap.set("n", "-", function()
    oil.open()
  end, { desc = "Open parent directory" })
end)
