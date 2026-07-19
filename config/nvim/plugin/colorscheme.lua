vim.pack.add({
  "https://github.com/EdenEast/nightfox.nvim",
})

require("nightfox").setup();

-- Mirror ghostty's `dark:Duskfox, light:Dawnfox`, following the terminal background.
local function apply()
  vim.cmd.colorscheme(vim.o.background == "light" and "dawnfox" or "duskfox")
end

vim.api.nvim_create_autocmd("OptionSet", { pattern = "background", callback = apply })
apply()
