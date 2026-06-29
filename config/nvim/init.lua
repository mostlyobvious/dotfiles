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

-- vim.o.autocomplete = true
-- vim.o.completeopt = "menu,menuone,noselect,nearest"
-- vim.cmd("set completeopt+=noselect")

vim.keymap.set("n", "<Leader>vn", "<Cmd>e ~/.config/nvim<CR>", { desc = "Edit nvim" })
vim.keymap.set("n", "<Leader>vf", "<Cmd>e ~/.config/fish<CR>", { desc = "Edit fish" })
vim.keymap.set("t", "<Esc>", [[<C-\>][<C-n>]])

-- vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist)
-- vim.keymap.set("n", "<leader>Q", vim.diagnostic.setqflist)

vim.api.nvim_create_autocmd("WinEnter", {
  pattern = "*",
  callback = function()
    vim.o.cursorline = true
  end,
})
vim.api.nvim_create_autocmd("WinLeave", {
  pattern = "*",
  callback = function()
    vim.o.cursorline = false
  end,
})
vim.api.nvim_create_autocmd("TextYankPost", {
  pattern = "*",
  callback = function()
    vim.highlight.on_yank({ timeout = 150 })
  end,
})
vim.api.nvim_create_autocmd("InsertLeave", {
  pattern = "*",
  callback = function()
    vim.o.paste = false
  end,
})

vim.diagnostic.config({
  virtual_lines = { current_line = true },
  underline = false,
  update_in_insert = false,
})

-- vim.api.nvim_create_autocmd("LspAttach", {
--   callback = function(ev)
--     -- local client = vim.lsp.get_client_by_id(ev.data.client_id)
--     -- if client:supports_method("textDocument/completion") then
--     --   vim.lsp.completion.enable(true, client.id, ev.buf, { autotrigger = true })
--     -- end
--
--     -- vim.keymap.set("n", "so", require("telescope.builtin").lsp_references, { buffer = ev.buf, desc = "References" })
--   end,
-- })

vim.lsp.enable({
  "elmls",
  "lua_ls",
  "ruby_lsp",
  "tailwindcss",
  "gopls",
})

vim.cmd.packadd("nvim.difftool")

require("vim._core.ui2").enable({})
