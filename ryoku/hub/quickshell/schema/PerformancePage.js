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
        "desc": "",
        "ctl": "sw",
        "src": "performance.json"
    },
    {
        "tab": "",
        "group": "LOW POWER",
        "key": "reduceMotion",
        "label": "Reduce motion - make transitions instant (no per-frame animation repaints)",
        "desc": "",
        "ctl": "sw",
        "src": "performance.json"
    },
    {
        "tab": "",
        "group": "LOW POWER",
        "key": "disableBlur",
        "label": "Disable blur - shell effects and the compositor backdrop blur (the biggest GPU saving)",
        "desc": "",
        "ctl": "sw",
        "src": "performance.json"
    },
    {
        "tab": "",
        "group": "LOW POWER",
        "key": "disableShadows",
        "label": "Disable shadows - shell drop shadows and the compositor window shadow",
        "desc": "",
        "ctl": "sw",
        "src": "performance.json"
    },
    {
        "tab": "",
        "group": "DESKTOP WIDGETS",
        "key": "unloadWidgetsWhenCovered",
        "label": "Hide desktop widgets while windows cover the desktop (frees their memory; they reappear on an empty desktop)",
        "desc": "",
        "ctl": "sw",
        "src": "performance.json"
    },
    {
        "tab": "",
        "group": "VISUALISER",
        "key": "freezeVisualizerWhenIdle",
        "label": "Freeze the visualiser when no audio is playing",
        "desc": "",
        "ctl": "sw",
        "src": "performance.json"
    },
    {
        "tab": "",
        "group": "VISUALISER",
        "key": "unloadVisualizerWhenSilent",
        "label": "Unload the visualiser to free memory when silent (brief delay when audio resumes)",
        "desc": "",
        "ctl": "sw",
        "src": "performance.json"
    },
    {
        "tab": "",
        "group": "BAR",
        "key": "freezePillWhenIdle",
        "label": "Freeze the glowing bead animation while the bar is idle",
        "desc": "",
        "ctl": "sw",
        "src": "performance.json"
    },
    {
        "tab": "",
        "group": "LAUNCHER & OVERVIEW",
        "key": "unloadLauncherWhenIdle",
        "label": "Unload the launcher to free its memory when idle (brief delay on the next open)",
        "desc": "",
        "ctl": "sw",
        "src": "performance.json"
    },
    {
        "tab": "",
        "group": "LAUNCHER & OVERVIEW",
        "key": "unloadOverviewWhenIdle",
        "label": "Unload the workspace overview to free its memory when idle (brief delay on the next open)",
        "desc": "",
        "ctl": "sw",
        "src": "performance.json"
    }
];
