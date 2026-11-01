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
      format = {
        defaultConfig = {
          indent_style = "space",
          indent_size = "2",
          quote_style = "double",
          max_line_length = "120",
          end_of_line = "lf",
          trailing_table_separator = "smart",
          call_arg_parentheses = "keep",
        },
      },
    },
  },
}
