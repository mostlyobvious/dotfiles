require("lazyload").on_vim_enter(function()
  vim.pack.add({
    "https://github.com/nvim-telescope/telescope.nvim",
    "https://github.com/nvim-lua/plenary.nvim",
    -- "https://github.com/nvim-telescope/telescope-fzf-native.nvim",
    -- "https://github.com/nvim-telescope/telescope-ui-select.nvim",
  })

  -- vim.api.nvim_create_autocmd('PackChanged', {
  --   callback = function(ev)
  --     local name, kind = ev.data.spec.name, ev.data.kind
  --     if name == 'nvim-treesitter' and kind == 'update' then
  --       if not ev.data.active then vim.cmd.packadd('nvim-treesitter') end
  --       vim.cmd('TSUpdate')
  --     end
  --   end
  -- })

  local telescope = require("telescope")
  local builtin = require("telescope.builtin")

  telescope.setup({
    defaults = {
      file_ignore_patterns = { "COMMIT_EDITMSG" },
    },
    pickers = {
      find_files = {
        theme = "dropdown",
        find_command = { "rg", "--files", "--iglob", "!.git", "--hidden" },
      },
      buffers = {
        theme = "dropdown",
        sort_lastused = true,
      },
      live_grep = {
        theme = "dropdown",
      },
      oldfiles = {
        theme = "dropdown",
        only_cwd = true,
      },
      grep_string = {
        theme = "dropdown",
      },
      current_buffer_fuzzy_find = {
        theme = "dropdown",
      },
    },
    extensions = {
      ["ui-select"] = {
        require("telescope.themes").get_dropdown({}),
      },
    },
  })

  -- telescope.load_extension("fzf")
  -- telescope.load_extension("ui-select")

  vim.keymap.set("n", "<leader>p", builtin.find_files, { desc = "Find files" })
  vim.keymap.set("n", "<leader>e", builtin.oldfiles, { desc = "Old files" })
  vim.keymap.set("n", "<leader>b", builtin.buffers, { desc = "Buffers" })

  local function visual_selection()
    local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
    return table.concat(lines, "")
  end

  vim.keymap.set("n", "<leader>g", builtin.current_buffer_fuzzy_find)
  vim.keymap.set("v", "<leader>g", function()
    builtin.current_buffer_fuzzy_find({ default_text = visual_selection() })
  end)

  vim.keymap.set("n", "<leader>G", builtin.live_grep)
  vim.keymap.set("v", "<leader>G", function()
    builtin.grep_string({ search = visual_selection() })
  end)
end)
