local home = os.getenv("HOME")
local ok, wc = pcall(dofile, home .. "/.cache/wallust/hypr-colors.lua")
if not ok then wc = nil end

local function border(hex, fallback)
  if type(hex) ~= "string" then hex = fallback end
  return "rgb(" .. hex:gsub("#", "") .. ")"
end

local active   = border(wc and wc.active, "#e0563b")
local inactive = border(wc and wc.inactive, "#313a4d")

-- Low-power switches, read from the shell's performance.json (the file Ryoku
-- Settings' Performance page writes). A flat-JSON pattern match keeps this
-- dependency-free; a missing file or key reads false. Compositor blur and shadow
-- are the heaviest present-time GPU cost, so lowPowerMode (or the individual
-- disableBlur / disableShadows) strips them here for weak GPUs. The Performance
-- page runs `hyprctl reload` on toggle so this re-reads live; on login it applies
-- on first parse.
local function perf_flag(key)
  local f = io.open(home .. "/.config/ryoku/performance.json", "r")
  if not f then return false end
  local s = f:read("*a")
  f:close()
  return s:match('"' .. key .. '"%s*:%s*true') ~= nil
end
local low_power = perf_flag("lowPowerMode")
local no_blur   = low_power or perf_flag("disableBlur")
local no_shadow = low_power or perf_flag("disableShadows")

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
      enabled      = not no_shadow,
      range        = 45,
      render_power = 4,
      color        = 0xd10a0807,
    },
    blur             = {
      enabled           = not no_blur,
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
  blur    = not no_blur,
  no_anim = true,
})

-- the workspace overview (qs -c overview, Super+Tab) is a full-screen layer-shell
-- expo: blur the desktop behind it so only the workspace cells and their live
-- window previews read on top. QML drives its open/close, so suppress Hyprland's
-- own layer animation (no double move).
hl.layer_rule({
  name    = "overview-blur",
  match   = { namespace = "overview" },
  blur    = not no_blur,
  no_anim = true,
})

-- The wallpaper rides the background layer: the awww image daemon and the
-- mpvpaper/phonto video daemons each map a surface there, and switching
-- image<->live maps one over the other. The global `layers` animation is
-- `popin 90%`, which scale-pops a fullscreen wallpaper surface in/out and reads
-- as a flicker. Override it to a pure `fade` for the wallpaper namespaces so the
-- surfaces crossfade instead (the video fades in over the image, and out to
-- reveal it), matching the switcher's own fade.
hl.layer_rule({
  name      = "wallpaper-crossfade",
  match     = { namespace = "^(awww-daemon|mpvpaper|phonto)$" },
  animation = "fade",
})
