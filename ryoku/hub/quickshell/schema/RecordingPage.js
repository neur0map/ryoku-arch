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
        "desc": "Frames captured per second, higher is smoother but files are larger",
        "ctl": "step",
        "src": "recording.json\")",
        "unit": "fps"
    },
    {
        "tab": "",
        "group": "QUALITY",
        "key": "framerateMode",
        "label": "Framerate mode",
        "desc": "Constant plays everywhere, variable is smaller but may import as 30fps",
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
        "desc": "Higher settings look crisper but make larger files",
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
        "desc": "H.264 plays anywhere, HEVC and AV1 are crisper, AV1 needs a newer GPU",
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
        "desc": "GPU encoding barely loads the CPU, pick CPU if the GPU encoder fails",
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
        "desc": "The mouse pointer is drawn into the video when on, hidden when off",
        "ctl": "sw",
        "src": "recording.json"
    }
];
