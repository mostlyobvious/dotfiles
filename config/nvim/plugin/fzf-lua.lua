require("lazyload").on_vim_enter(function()
  vim.pack.add({
    "https://github.com/ibhagwan/fzf-lua",
  })

  local fzf = require("fzf-lua")

  fzf.setup({
    "telescope",
    winopts = {
      width = 80,
      height = 0.6,
      preview = { layout = "vertical", vertical = "up:50%" },
    },
    fzf_opts = { ["--layout"] = "reverse" },
    defaults = { file_icons = false },
    file_ignore_patterns = { "COMMIT_EDITMSG" },
    oldfiles = { cwd_only = true },
  })

  local function visual_selection()
    local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
    return table.concat(lines, "")
  end

  vim.keymap.set("n", "<leader>p", fzf.files, { desc = "Find files" })
  vim.keymap.set("n", "<leader>e", fzf.oldfiles, { desc = "Old files" })
  vim.keymap.set("n", "<leader>b", fzf.buffers, { desc = "Buffers" })

  vim.keymap.set("n", "<leader>g", fzf.blines)
  vim.keymap.set("v", "<leader>g", function()
    fzf.blines({ query = visual_selection() })
  end)

  vim.keymap.set("n", "<leader>G", fzf.live_grep)
  vim.keymap.set("v", "<leader>G", function()
    fzf.grep({ search = visual_selection() })
  end)
end)
