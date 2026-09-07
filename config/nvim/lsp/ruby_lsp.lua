return {
  cmd = { "ruby-lsp" },
  filetypes = { "ruby" },
  root_markers = { "Gemfile", ".git" },
  formatter = "syntax_tree",
  linters = { "rubocop" },
  addonSettings = {
    ["Ruby LSP Rails"] = {
      enablePendingMigrationsPrompt = false,
    },
  },
}
