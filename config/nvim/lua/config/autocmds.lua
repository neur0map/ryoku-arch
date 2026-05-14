vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("ryoku-highlight-yank", { clear = true }),
  callback = function()
    vim.highlight.on_yank({ timeout = 180 })
  end,
})
