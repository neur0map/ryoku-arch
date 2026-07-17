.pragma library

// DictationPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "DICTATION",
        "key": "enabled",
        "label": "Voice typing",
        "desc": "",
        "ctl": "sw",
        "src": " disable --now (off). Read back via `systemctl --user is-enabled --quiet voxtype.service`."
    },
    {
        "tab": "",
        "group": "ENGINE & MODEL",
        "key": "# ryoku-preset: <key>",
        "label": "(no visible label \u2014 the section title \"ENGINE & MODEL\" is the only label; the control is a click-to-select card list)",
        "desc": "",
        "ctl": "seg",
        "src": "voxtype.go, mode 0600, atomicWrite. Selection is persisted ONLY as a TOML *comment* marker `# ryoku-preset: <key>` and read back by selectedPreset() scanning for that comment prefix.",
        "opts": [
            "whisper-fast",
            "whisper-accurate",
            "openai"
        ]
    },
    {
        "tab": "",
        "group": "ENGINE & MODEL",
        "key": "whisper.model = \"base.en\" + whisper.language = \"en\"",
        "label": "Whisper \u2014 Fast",
        "desc": "",
        "ctl": "action",
        "src": "ggml-base.en.bin"
    },
    {
        "tab": "",
        "group": "ENGINE & MODEL",
        "key": "whisper.model = \"large-v3-turbo\" + whisper.language = \"auto\"",
        "label": "Whisper \u2014 Accurate",
        "desc": "",
        "ctl": "action",
        "src": "ggml-large-v3-turbo.bin"
    },
    {
        "tab": "",
        "group": "ENGINE & MODEL",
        "key": "whisper.mode = \"remote\" + whisper.remote_model = \"whisper-1\" + whisper.remote_endpoint = \"https://api.openai.com/v1\"",
        "label": "OpenAI API",
        "desc": "",
        "ctl": "action",
        "src": "config.toml"
    },
    {
        "tab": "",
        "group": "API KEY",
        "key": "remote_api_key",
        "label": "OpenAI API key",
        "desc": "",
        "ctl": "text",
        "src": "config.toml, under [whisper], mode 0600. Also satisfied read-only by env VOXTYPE_WHISPER_API_KEY."
    },
    {
        "tab": "",
        "group": "API KEY",
        "key": "remote_api_key",
        "label": "Save key",
        "desc": "",
        "ctl": "action",
        "src": "config.toml"
    },
    {
        "tab": "",
        "group": "(install empty-state, not a SettingSection)",
        "key": "",
        "label": "Install Voxtype",
        "desc": "",
        "ctl": "action",
        "src": "none (package manager)"
    },
    {
        "tab": "",
        "group": "PACKAGE",
        "key": "",
        "label": "Remove Voxtype",
        "desc": "",
        "ctl": "action",
        "src": "none (package manager + systemd unit removal)"
    }
];
