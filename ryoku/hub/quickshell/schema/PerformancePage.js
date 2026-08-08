.pragma library

// PerformancePage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "LOW POWER",
        "key": "lowPowerMode",
        "label": "Low power mode - strip every heavy effect at once (blur, shadows, animations). The potato switch: implies all four toggles below, so a weak GPU runs the shell lag-free.",
        "desc": "Forces every freeze, reduce and disable switch on; unloads stay manual",
        "ctl": "sw",
        "src": "performance.json"
    },
    {
        "tab": "",
        "group": "LOW POWER",
        "key": "reduceMotion",
        "label": "Reduce motion - make transitions instant (no per-frame animation repaints)",
        "desc": "Shell transitions land instantly; Hyprland window animations keep playing",
        "ctl": "sw",
        "src": "performance.json"
    },
    {
        "tab": "",
        "group": "LOW POWER",
        "key": "disableBlur",
        "label": "Disable blur - shell effects and the compositor backdrop blur (the biggest GPU saving)",
        "desc": "Kills the frosted-glass look everywhere; Hyprland reloads to apply it now",
        "ctl": "sw",
        "src": "performance.json"
    },
    {
        "tab": "",
        "group": "LOW POWER",
        "key": "disableShadows",
        "label": "Disable shadows - shell drop shadows and the compositor window shadow",
        "desc": "Each shadow is its own GPU blur pass, so flat surfaces draw much cheaper",
        "ctl": "sw",
        "src": "performance.json"
    },
    {
        "tab": "",
        "group": "DESKTOP WIDGETS",
        "key": "unloadWidgetsWhenCovered",
        "label": "Hide desktop widgets while windows cover the desktop (frees their memory; they reappear on an empty desktop)",
        "desc": "Parks only when every monitor is covered; the return is always instant",
        "ctl": "sw",
        "src": "performance.json"
    },
    {
        "tab": "",
        "group": "VISUALISER",
        "key": "freezeVisualizerWhenIdle",
        "label": "Freeze the visualiser when no audio is playing",
        "desc": "Halts the idle animation, whose repaints otherwise leak memory over time",
        "ctl": "sw",
        "src": "performance.json"
    },
    {
        "tab": "",
        "group": "VISUALISER",
        "key": "unloadVisualizerWhenSilent",
        "label": "Unload the visualiser to free memory when silent (brief delay when audio resumes)",
        "desc": "Kills the whole process after 30s of silence, reclaiming around 250 MB",
        "ctl": "sw",
        "src": "performance.json"
    },
    {
        "tab": "",
        "group": "BAR",
        "key": "freezePillWhenIdle",
        "label": "Freeze the glowing bead animation while the bar is idle",
        "desc": "Also drops the bead's live blur layer, so an idle bar costs no GPU frames",
        "ctl": "sw",
        "src": "performance.json"
    },
    {
        "tab": "",
        "group": "LAUNCHER & OVERVIEW",
        "key": "unloadLauncherWhenIdle",
        "label": "Unload the launcher to free its memory when idle (brief delay on the next open)",
        "desc": "Frees about 250 MB after a minute hidden; the next open cold-starts",
        "ctl": "sw",
        "src": "performance.json"
    },
    {
        "tab": "",
        "group": "LAUNCHER & OVERVIEW",
        "key": "unloadOverviewWhenIdle",
        "label": "Unload the workspace overview to free its memory when idle (brief delay on the next open)",
        "desc": "Frees about 250 MB after a minute hidden; next Super+Tab cold-starts it",
        "ctl": "sw",
        "src": "performance.json"
    }
];
