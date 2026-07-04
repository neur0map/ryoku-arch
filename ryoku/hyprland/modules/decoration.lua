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
    gaps_in                 = 12,
    gaps_out                = 18,
    border_size             = 2,
    layout                  = "dwindle",
    resize_on_border        = true,
    ["col.active_border"]   = active,
    ["col.inactive_border"] = inactive,
  },
  decoration = {
    rounding         = 2,
    rounding_power   = 4,
    active_opacity   = 1,
    inactive_opacity = 0.94,
    shadow           = {
      enabled      = true,
      range        = 45,
      render_power = 4,
      color        = 0xd10a0807,
    },
    blur             = {
      enabled           = true,
      size              = 4,
      passes            = 1,
      vibrancy          = 0.17,
      noise             = 0.01,
      new_optimizations = true,
    },
  },
})

-- the launcher is a translucent layer-shell overlay; blur its backdrop so the
-- card reads against any wallpaper. its open/close is QML-driven, so suppress
-- Hyprland's own layer animation to avoid a double move.
hl.layer_rule({
  name    = "launcher-blur",
  match   = { namespace = "launcher" },
  blur    = true,
  no_anim = true,
})

-- the workspace overview (qs -c overview, Super+Tab) is a full-screen layer-shell
-- expo: blur the desktop behind it so only the workspace cells and their live
-- window previews read on top. QML drives its open/close, so suppress Hyprland's
-- own layer animation (no double move).
hl.layer_rule({
  name    = "overview-blur",
  match   = { namespace = "overview" },
  blur    = true,
  no_anim = true,
})
