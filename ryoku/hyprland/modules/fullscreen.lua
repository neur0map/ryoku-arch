-- Chromium/Electron strand a window in maximize (mode 1) when leaving page
-- fullscreen; Ryoku has no maximize, so reset it to normal (issue 13322).
hl.on("window.fullscreen", function(w)
    if w and w.fullscreen == 1 then
        hl.dispatch(hl.dsp.window.fullscreen_state({ internal = 0, client = 0, action = "set", window = w }))
    end
end)
