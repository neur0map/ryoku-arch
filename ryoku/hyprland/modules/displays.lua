-- hotplug = redo DPI autoscale (login alone misses it) + repaint the wallpaper
-- so the new output isn't blank. the sleep 1 lets autoscale settle the mode
-- first, else awww caches the image at the wrong resolution.
hl.on("monitor.added", function()
    hl.exec_cmd("command -v ryoku-monitor >/dev/null 2>&1 && ryoku-monitor autoscale")
    hl.exec_cmd("command -v ryoku-shell >/dev/null 2>&1 && { sleep 1; ryoku-shell wallpaper refresh; }")
end)
