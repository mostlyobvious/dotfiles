-- nvim-treesitter does not support lazy-loading, and parsers must match its revision.
vim.api.nvim_create_autocmd("PackChanged", {
  callback = function(ev)
    if ev.data.spec.name == "nvim-treesitter" and ev.data.kind == "update" then
      vim.schedule(function()
        vim.cmd("TSUpdate")
      end)
    end
  end,
})

vim.pack.add({
  "https://github.com/nvim-treesitter/nvim-treesitter",
  "https://github.com/nvim-treesitter/nvim-treesitter-context",
})

require("nvim-treesitter").install({
  "bash",
  "css",
  "elm",
  "embedded_template",
  "fish",
  "go",
  "gomod",
  "html",
  "javascript",
  "json",
  "nix",
  "python",
  "ruby",
  "rust",
  "sql",
  "tsx",
  "typescript",
  "yaml",
})

vim.api.nvim_create_autocmd("FileType", {
  callback = function(ev)
    pcall(vim.treesitter.start, ev.buf)
  end,
})
