-- Re-derive DPI scaling when a display is hotplugged, not only at login.
hl.on("monitor.added", function()
    hl.exec_cmd("command -v ryoku-monitor >/dev/null 2>&1 && ryoku-monitor autoscale")
end)
