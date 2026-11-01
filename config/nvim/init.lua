vim.g.mapleader = ","

vim.opt.shortmess:append({ I = true })

vim.o.exrc = true
vim.o.shell = "fish"
vim.o.cursorline = true
vim.o.splitbelow = true
vim.o.splitright = true
vim.o.updatetime = 250

vim.o.ignorecase = true

vim.wo.number = true
vim.wo.signcolumn = "yes"

vim.keymap.set("n", "<Leader>vn", "<Cmd>e ~/.config/nvim<CR>", { desc = "Edit nvim" })
vim.keymap.set("n", "<Leader>vf", "<Cmd>e ~/.config/fish<CR>", { desc = "Edit fish" })
vim.keymap.set("t", "<Esc>", [[<C-\><C-n>]])

vim.api.nvim_create_autocmd("WinEnter", {
  callback = function()
    vim.o.cursorline = true
  end,
})
vim.api.nvim_create_autocmd("WinLeave", {
  callback = function()
    vim.o.cursorline = false
  end,
})
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.hl.on_yank({ timeout = 150 })
  end,
})

vim.diagnostic.config({
  virtual_lines = { current_line = true },
  underline = false,
  update_in_insert = false,
})

vim.lsp.enable({
  "elmls",
  "gopls",
  "jsonls",
  "lua_ls",
  "pyright",
  "ruff",
  "ruby_lsp",
  "rust_analyzer",
  "tailwindcss",
  "yamlls",
})

vim.cmd.packadd("nvim.difftool")

require("vim._core.ui2").enable({})
