local map = vim.keymap.set

map("n", "<leader>rr", function()
  if pcall(vim.cmd.colorscheme, "ryoku-shell") then
    vim.notify("Ryoku theme reloaded", vim.log.levels.INFO)
  else
    vim.notify("Ryoku theme has not been generated yet", vim.log.levels.WARN)
  end
end, {
  desc = "Reload Ryoku theme",
})
