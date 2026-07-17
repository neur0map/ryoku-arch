.pragma library

// RecordingPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "QUALITY",
        "key": "fps",
        "label": "Framerate",
        "desc": "",
        "ctl": "step",
        "src": "recording.json\")",
        "unit": "fps"
    },
    {
        "tab": "",
        "group": "QUALITY",
        "key": "framerateMode",
        "label": "Framerate mode",
        "desc": "",
        "ctl": "seg",
        "src": "recording.json",
        "opts": [
            "cfr",
            "vfr"
        ]
    },
    {
        "tab": "",
        "group": "QUALITY",
        "key": "quality",
        "label": "Quality",
        "desc": "",
        "ctl": "seg",
        "src": "recording.json",
        "opts": [
            "medium",
            "high",
            "very_high",
            "ultra"
        ]
    },
    {
        "tab": "",
        "group": "QUALITY",
        "key": "codec",
        "label": "Codec",
        "desc": "",
        "ctl": "seg",
        "src": "recording.json",
        "opts": [
            "h264",
            "hevc",
            "av1"
        ]
    },
    {
        "tab": "",
        "group": "ENCODER",
        "key": "encoder",
        "label": "Encoder",
        "desc": "",
        "ctl": "seg",
        "src": "recording.json",
        "opts": [
            "gpu",
            "cpu"
        ]
    },
    {
        "tab": "",
        "group": "ENCODER",
        "key": "cursor",
        "label": "Show the cursor in recordings",
        "desc": "",
        "ctl": "sw",
        "src": "recording.json"
    }
];
