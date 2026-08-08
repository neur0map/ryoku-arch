-- Ryoku: the editor follows the live wallpaper palette.
--
-- The theme daemon writes the 16-colour base16 set to ~/.cache/ryoku/colors.json
-- on every palette change -- the same file kitty and the shell read. We feed it
-- into tokyonight's on_colors so nvim matches the terminal, keep habamax as the
-- safety net, and re-tint a running editor when the palette changes.
local uv = vim.uv or vim.loop
local COLORS = vim.fn.expand("~/.cache/ryoku/colors.json")

local function palette()
  local f = io.open(COLORS, "r")
  if not f then
    return nil
  end
  local raw = f:read("*a")
  f:close()
  local ok, p = pcall(vim.json.decode, raw)
  if not ok or type(p) ~= "table" or not p.color0 then
    return nil
  end
  return p
end

-- map the base16 palette onto tokyonight's colour slots (run on every apply)
local function tint(c)
  local p = palette()
  if not p then
    return
  end
  c.bg, c.bg_dark, c.bg_float = p.color0, p.color0, p.color0
  c.bg_popup, c.bg_sidebar, c.bg_statusline = p.color0, p.color0, p.color0
  c.fg, c.fg_dark, c.fg_gutter, c.comment = p.color7, p.color8, p.color8, p.color8
  c.red, c.green, c.yellow = p.color1, p.color2, p.color3
  c.blue, c.magenta, c.cyan = p.color4, p.color5, p.color6
  c.purple, c.teal, c.orange = p.color5, p.color6, p.color3
end

-- Re-tint when the daemon rewrites the palette. Re-running :colorscheme re-invokes
-- on_colors (which re-reads the file), so no re-setup is needed; mtime-gated so a
-- focus change without a palette change never repaints.
local seen = (uv.fs_stat(COLORS) or {}).mtime
vim.api.nvim_create_autocmd("FocusGained", {
  callback = function()
    local st = uv.fs_stat(COLORS)
    if not st then
      return
    end
    if seen and st.mtime.sec == seen.sec and st.mtime.nsec == seen.nsec then
      return
    end
    seen = st.mtime
    local name = vim.g.colors_name
    if name and name:find("tokyonight") then
      pcall(vim.cmd.colorscheme, name)
    end
  end,
})

return {
  {
    "folke/tokyonight.nvim",
    opts = function(_, opts)
      opts.style = opts.style or "night"
      opts.on_colors = tint
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        if not pcall(vim.cmd.colorscheme, "tokyonight-night") then
          vim.cmd.colorscheme("habamax")
        end
      end,
    },
  },
}
