require("lazyload").on_vim_enter(function()
  vim.pack.add({
    { src = "https://github.com/Saghen/blink.cmp", version = vim.version.range("1.*") },
  })

  require("blink.cmp").setup({
    keymap = {
      preset = "enter",
      ["<C-k>"] = { "select_prev", "fallback" },
      ["<C-j>"] = { "select_next", "fallback" },
      ["<Tab>"] = { "accept", "fallback" },
      ["<C-c>"] = { "cancel", "fallback" },
    },
    completion = {
      documentation = { auto_show = false },
      list = { selection = { auto_insert = false } },
    },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
    -- fuzzy = { implementation = "prefer_rust_with_warning" },
    fuzzy = { implementation = "lua" },
  })
end)
