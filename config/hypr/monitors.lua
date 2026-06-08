-- Managed by Ryoku Display settings (ryoku-monitor).
-- Edits here may be overwritten; use Settings > Display.
--
-- No per-output line is shipped on purpose: monitors use the catch-all below until
-- Settings > Display writes explicit hl.monitor{} entries, which take precedence.
-- The catch-all is scale 1 so a panel is never over-zoomed. ryoku-monitor autoscale
-- runs at session start and raises the scale of high-DPI panels by their real pixel
-- density (resolution / physical size) instead of a hardcoded value, so low-DPI
-- external monitors stay at 1x while dense laptop panels get bumped.
-- XWayland crispness/size is handled via force_zero_scaling + per-app device scale.

-- Catch-all for monitors not configured above (hotplug-friendly).
hl.monitor({
    output = "",
    mode = "highrr",
    position = "auto",
    scale = 1,
})
