.pragma library

// GpuPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "RYOKU RENDERS ON",
        "key": "AQ_DRM_DEVICES",
        "label": "Graphics mode",
        "desc": "Which GPU the desktop renders on, takes effect at your next login",
        "ctl": "seg",
        "src": "gpu.lua (override path via $RYOKU_GPU_CONF; base honours $XDG_CONFIG_HOME)",
        "opts": [
            "hybrid",
            "performance",
            "passthrough"
        ]
    },
    {
        "tab": "",
        "group": "TUNING \u00b7 THIS SESSION",
        "key": "",
        "label": "Power limit / TDP",
        "desc": "GPU power budget in watts, applied live for this session (NVIDIA nvidia-smi, AMD sysfs cap)",
        "ctl": "slid",
        "src": "ryoku-hub gpu tune (runtime, resets on reboot)"
    },
    {
        "tab": "",
        "group": "TUNING \u00b7 THIS SESSION",
        "key": "",
        "label": "Performance level",
        "desc": "AMD power_dpm_force_performance_level: auto, low, or high",
        "ctl": "seg",
        "src": "ryoku-hub gpu tune (runtime, resets on reboot)"
    },
    {
        "tab": "",
        "group": "TUNING \u00b7 THIS SESSION",
        "key": "",
        "label": "Thermal profile",
        "desc": "Chassis fan and power envelope: quiet, balanced, or performance (ACPI platform_profile)",
        "ctl": "seg",
        "src": "ryoku-hub gpu tune (runtime, resets on reboot)"
    },
    {
        "tab": "",
        "group": "TUNING \u00b7 THIS SESSION",
        "key": "",
        "label": "Persistence mode",
        "desc": "Keep the NVIDIA driver initialised so the GPU stays responsive",
        "ctl": "sw",
        "src": "ryoku-hub gpu tune (runtime, resets on reboot)"
    },
    {
        "tab": "",
        "group": "TUNING \u00b7 THIS SESSION",
        "key": "",
        "label": "Overclock / undervolt / clock lock / fan (Advanced)",
        "desc": "GPU clock and fan control, gated behind a per-session warning; can misbehave, resets on reboot",
        "ctl": "slid",
        "src": "ryoku-hub gpu tune (runtime, resets on reboot)"
    },
    {
        "tab": "",
        "group": "TUNING \u00b7 THIS SESSION",
        "key": "",
        "label": "Presets (Quiet / Balanced / Performance / custom)",
        "desc": "Save and apply named tuning bundles; built-ins adapt to whatever knobs your hardware exposes",
        "ctl": "action",
        "src": "~/.config/ryoku/gpu-presets.json"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Readiness checks / Hide readiness checks (disclosure)",
        "desc": "",
        "ctl": "sw",
        "src": "none (transient page state: page.showChecks)"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Disable passthrough",
        "desc": "",
        "ctl": "action",
        "src": "qemu"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Review changes",
        "desc": "",
        "ctl": "action",
        "src": "reads nothing; prints a plan"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Enable passthrough",
        "desc": "",
        "ctl": "action",
        "src": "kvm; enables libvirtd; kvmfr static_size_mb=128"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Close",
        "desc": "",
        "ctl": "action",
        "src": "none"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Recheck",
        "desc": "",
        "ctl": "action",
        "src": "none"
    },
    {
        "tab": "",
        "group": "(no SettingSection \u2014 floating error column under the hero card)",
        "key": "",
        "label": "Retry",
        "desc": "",
        "ctl": "action",
        "src": "none"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Passthrough status line (verdict readout)",
        "desc": "",
        "ctl": "readout",
        "src": "`ryoku-hub gpu caps` -> caps.verdict"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Readiness checks dossier rows (Repeater over caps.checks)",
        "desc": "",
        "ctl": "readout",
        "src": "hwcaps.go buildChecks)"
    },
    {
        "tab": "",
        "group": "RYOKU RENDERS ON",
        "key": "",
        "label": "Graphics mode explainer (per-mode helper text)",
        "desc": "",
        "ctl": "readout",
        "src": "derived from page.mode + page.dgpuName"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Passthrough section intro",
        "desc": "",
        "ctl": "readout",
        "src": "static copy + page.dgpuName"
    }
];
