local home = os.getenv("HOME")
local ok, wc = pcall(dofile, home .. "/.cache/wallust/hypr-colors.lua")
if not ok then wc = nil end

local function border(hex, fallback)
  if type(hex) ~= "string" then hex = fallback end
  return "rgb(" .. hex:gsub("#", "") .. ")"
end

local active   = border(wc and wc.active, "#e0563b")
local inactive = border(wc and wc.inactive, "#313a4d")

hl.config({
  general = {
    gaps_in                 = 8,
    -- Per side (top right bottom left): 26 keeps the ~10px sliver past the 16px
    -- frame on the sides and bottom; the top is tighter so tiles sit closer
    -- under the island.
    gaps_out                = { top = 6, right = 26, bottom = 26, left = 26 },
    border_size             = 3,
    layout                  = "dwindle",
    resize_on_border        = true,
    ["col.active_border"]   = active,
    ["col.inactive_border"] = inactive,
  },
  decoration = {
    rounding         = 16,
    rounding_power   = 4,
    active_opacity   = 0.96,
    inactive_opacity = 0.90,
    shadow           = {
      enabled      = true,
      range        = 30,
      render_power = 4,
      color        = 0xd10a0807,
    },
    blur             = {
      enabled           = true,
      size              = 8,
      passes            = 3,
      vibrancy          = 0.17,
      noise             = 0.01,
      new_optimizations = true,
    },
  },
})

hl.layer_rule({
  name    = "sidebar-noanim",
  match   = { namespace = "sidebar" },
  no_anim = true,
})

hl.layer_rule({
  name    = "sidebar-inhibit-noanim",
  match   = { namespace = "sidebar-inhibit" },
  no_anim = true,
})
