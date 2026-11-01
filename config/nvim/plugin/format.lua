local function can_format(bufnr)
  return #vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/formatting" }) > 0
end

vim.api.nvim_create_autocmd("BufWritePre", {
  callback = function(ev)
    if vim.g.disable_autoformat or vim.b[ev.buf].disable_autoformat or not can_format(ev.buf) then
      return
    end
    vim.lsp.buf.format({ bufnr = ev.buf, timeout_ms = 500 })
  end,
})

vim.api.nvim_create_user_command("FormatDisable", function(args)
  if args.bang then
    vim.b.disable_autoformat = true
  else
    vim.g.disable_autoformat = true
  end
end, {
  desc = "Disable autoformat-on-save",
  bang = true,
})

vim.api.nvim_create_user_command("FormatEnable", function()
  vim.b.disable_autoformat = false
  vim.g.disable_autoformat = false
end, {
  desc = "Re-enable autoformat-on-save",
})

vim.api.nvim_create_user_command("Format", function(args)
  local range = nil
  if args.count ~= -1 then
    local end_line = vim.api.nvim_buf_get_lines(0, args.line2 - 1, args.line2, true)[1]
    range = {
      start = { args.line1, 0 },
      ["end"] = { args.line2, end_line:len() },
    }
  end
  vim.lsp.buf.format({ async = true, range = range })
end, { range = true })
