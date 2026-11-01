local M = {}

local vim_enter_queue = {}

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    for _, fn in ipairs(vim_enter_queue) do
      vim.schedule(fn)
    end
    vim_enter_queue = nil
  end,
})

function M.on_vim_enter(fn)
  if vim_enter_queue then
    table.insert(vim_enter_queue, fn)
  else
    vim.schedule(fn)
  end
end

return M
