return {
  cmd = { "lua-language-server" },
  filetypes = { "lua" },
  root_markers = {
    ".stylua.toml",
    ".git",
  },
  settings = {
    Lua = {
      diagnostics = {
        globals = { "vim" },
      },
    },
  },
}
