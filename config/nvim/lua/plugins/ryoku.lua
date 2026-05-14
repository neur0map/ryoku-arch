local function ryoku_colorscheme()
  if pcall(vim.cmd.colorscheme, "ryoku-shell") then
    return
  end
  if pcall(vim.cmd.colorscheme, "tokyonight-night") then
    return
  end
  vim.cmd.colorscheme("habamax")
end

return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = ryoku_colorscheme,
    },
  },
}
