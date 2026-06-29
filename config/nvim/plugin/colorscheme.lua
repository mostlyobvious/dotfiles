vim.pack.add({
  "https://github.com/rose-pine/neovim",
})

require("rose-pine").setup({
  -- dark_variant = "moon",
  styles = {
    italic = false,
  },
});

vim.cmd("colorscheme rose-pine")
