return {
  cmd = { "ruby-lsp" },
  filetypes = { "ruby" },
  root_markers = { "Gemfile", ".git" },
  formatter = "standard",
  linters = { "standard" },
  addonSettings = {
    ["Ruby LSP Rails"] = {
      enablePendingMigrationsPrompt = false,
    },
  },
}
