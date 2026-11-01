local function zoom_in()
  if vim.fn.getcmdwintype() ~= "" then
    vim.notify("No zoom in command line window")
    return
  end
  if vim.fn.winnr("$") == 1 then
    vim.notify("Already only one window")
    return
  end
  local zoom = { tab = vim.api.nvim_get_current_tabpage(), showtabline = vim.o.showtabline }
  vim.cmd("tab sbuffer " .. vim.api.nvim_get_current_buf())
  vim.t.zoom = zoom
  vim.o.showtabline = 0
end

local function zoom_out()
  local zoom = vim.t.zoom
  vim.cmd.tabclose()
  if vim.api.nvim_tabpage_is_valid(zoom.tab) then
    vim.api.nvim_set_current_tabpage(zoom.tab)
  end
  vim.o.showtabline = zoom.showtabline
end

local function toggle()
  if vim.t.zoom then
    zoom_out()
  else
    zoom_in()
  end
end

vim.keymap.set("n", "<Leader><Leader>", toggle, { desc = "Zoom window" })
for _, count in ipairs({ "", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9" }) do
  vim.keymap.set("n", "<C-w>" .. count .. "o", toggle)
  vim.keymap.set("n", "<C-w>" .. count .. "<C-o>", toggle)
end
