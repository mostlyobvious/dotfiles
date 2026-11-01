return {
  cmd = { "tailwindcss-language-server", "--stdio" },
  filetypes = { "html", "css", "eruby", "javascript", "javascriptreact", "typescript", "typescriptreact" },
  root_markers = {
    { "tailwind.config.js", "tailwind.config.cjs", "tailwind.config.mjs", "tailwind.config.ts" },
    ".git",
  },
}
