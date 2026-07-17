.pragma library

// InputPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "KEYBOARD",
        "key": "input.kbLayout",
        "label": "Layout",
        "desc": "",
        "ctl": "seg",
        "src": "settings.lua (input.kb_layout)",
        "opts": [
            "<dynamic:"
        ]
    },
    {
        "tab": "",
        "group": "KEYBOARD",
        "key": "input.kbVariant",
        "label": "Style",
        "desc": "",
        "ctl": "seg",
        "src": "settings.lua (input.kb_variant)",
        "opts": [
            "\"\"",
            "<dynamic:"
        ]
    },
    {
        "tab": "",
        "group": "KEYBOARD",
        "key": "input.kbLayout",
        "label": "Second layout",
        "desc": "",
        "ctl": "seg",
        "src": "settings.lua (input.kb_layout)",
        "opts": [
            "\"\"",
            "<dynamic:"
        ]
    },
    {
        "tab": "",
        "group": "KEYBOARD",
        "key": "input.kbOptions",
        "label": "Switch layouts",
        "desc": "",
        "ctl": "seg",
        "src": "settings.lua (input.kb_options)",
        "opts": [
            "\"\"",
            "grp:alt_shift_toggle",
            "grp:win_space_toggle"
        ]
    },
    {
        "tab": "",
        "group": "KEYBOARD",
        "key": "input.numlockByDefault",
        "label": "Numlock on at login",
        "desc": "",
        "ctl": "sw",
        "src": "settings.lua (input.numlock_by_default)"
    },
    {
        "tab": "",
        "group": "KEY REMAPS",
        "key": "input.kbOptions",
        "label": "Caps Lock",
        "desc": "",
        "ctl": "chips",
        "src": "settings.lua (input.kb_options)",
        "opts": [
            "\"\"",
            "caps:escape",
            "ctrl:nocaps",
            "caps:swapescape",
            "caps:none"
        ]
    },
    {
        "tab": "",
        "group": "KEY REMAPS",
        "key": "input.kbOptions",
        "label": "Swap Alt and Super",
        "desc": "",
        "ctl": "sw",
        "src": "settings.lua (input.kb_options)"
    },
    {
        "tab": "",
        "group": "KEY REMAPS",
        "key": "input.kbOptions",
        "label": "Compose key",
        "desc": "",
        "ctl": "seg",
        "src": "settings.lua (input.kb_options)",
        "opts": [
            "\"\"",
            "compose:ralt",
            "compose:menu"
        ]
    },
    {
        "tab": "",
        "group": "KEY REMAPS",
        "key": "input.kbOptions",
        "label": "Extra options",
        "desc": "",
        "ctl": "text",
        "src": "settings.lua (input.kb_options)"
    },
    {
        "tab": "",
        "group": "KEY REMAPS",
        "key": "",
        "label": "Apply system-wide",
        "desc": "",
        "ctl": "action",
        "src": "vconsole.conf, via `localectl set-x11-keymap <kbLayout> \"\" <kbVariant> <kbOptions>`"
    },
    {
        "tab": "",
        "group": "KEY REMAPS",
        "key": "",
        "label": "Login screen and TTY keymap status",
        "desc": "",
        "ctl": "readout",
        "src": "shell"
    },
    {
        "tab": "",
        "group": "POINTER",
        "key": "input.sensitivity",
        "label": "Sensitivity",
        "desc": "",
        "ctl": "slid",
        "src": "settings.lua (input.sensitivity)",
        "lo": -1.0,
        "hi": 1.0
    },
    {
        "tab": "",
        "group": "POINTER",
        "key": "input.followMouse",
        "label": "Follow mouse",
        "desc": "",
        "ctl": "seg",
        "src": "settings.lua (input.follow_mouse)",
        "opts": [
            "0",
            "1",
            "2"
        ]
    },
    {
        "tab": "",
        "group": "POINTER",
        "key": "input.accelProfile",
        "label": "Acceleration",
        "desc": "",
        "ctl": "seg",
        "src": "settings.lua (input.accel_profile)",
        "opts": [
            "\"\"",
            "flat",
            "adaptive"
        ]
    },
    {
        "tab": "",
        "group": "POINTER",
        "key": "input.leftHanded",
        "label": "Left-handed buttons",
        "desc": "",
        "ctl": "sw",
        "src": "settings.lua (input.left_handed)"
    },
    {
        "tab": "",
        "group": "POINTER",
        "key": "input.mouseNaturalScroll",
        "label": "Natural scroll",
        "desc": "",
        "ctl": "sw",
        "src": "settings.lua (input.natural_scroll)"
    },
    {
        "tab": "",
        "group": "POINTER",
        "key": "input.mouseScrollFactor",
        "label": "Scroll speed",
        "desc": "",
        "ctl": "step",
        "src": "settings.lua (input.scroll_factor)",
        "lo": 0.2,
        "hi": 3.0
    },
    {
        "tab": "",
        "group": "POINTER",
        "key": "input.middleClickPaste",
        "label": "Middle-click pastes",
        "desc": "",
        "ctl": "sw",
        "src": "settings.lua"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.naturalScroll",
        "label": "Natural scroll",
        "desc": "",
        "ctl": "sw",
        "src": "settings.lua (input.touchpad.natural_scroll)"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.tapToClick",
        "label": "Tap to click",
        "desc": "",
        "ctl": "sw",
        "src": "settings.lua (input.touchpad.tap_to_click)"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.tapAndDrag",
        "label": "Tap and drag",
        "desc": "",
        "ctl": "sw",
        "src": "settings.lua (input.touchpad.tap_and_drag)"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.disableWhileTyping",
        "label": "Disable while typing",
        "desc": "",
        "ctl": "sw",
        "src": "settings.lua (input.touchpad.disable_while_typing)"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.clickfinger",
        "label": "Click by finger count",
        "desc": "",
        "ctl": "sw",
        "src": "settings.lua (input.touchpad.clickfinger_behavior)"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.middleEmulation",
        "label": "Emulate middle click",
        "desc": "",
        "ctl": "sw",
        "src": "settings.lua (input.touchpad.middle_button_emulation)"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.touchScrollFactor",
        "label": "Scroll speed",
        "desc": "",
        "ctl": "step",
        "src": "settings.lua (input.touchpad.scroll_factor)",
        "lo": 0.2,
        "hi": 3.0
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.workspaceSwipe",
        "label": "Swipe between workspaces",
        "desc": "",
        "ctl": "sw",
        "src": "settings.lua"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.swipeFingers",
        "label": "Swipe fingers",
        "desc": "",
        "ctl": "seg",
        "src": "settings.lua (hl.gesture fingers arg)",
        "opts": [
            "3",
            "4"
        ]
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.swipeInvert",
        "label": "Natural swipe direction",
        "desc": "",
        "ctl": "sw",
        "src": "settings.lua (gestures.workspace_swipe_invert)"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.swipeCreateNew",
        "label": "Swipe past the last workspace to add one",
        "desc": "",
        "ctl": "sw",
        "src": "settings.lua (gestures.workspace_swipe_create_new)"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.swipeDistance",
        "label": "Swipe distance",
        "desc": "",
        "ctl": "step",
        "src": "settings.lua (gestures.workspace_swipe_distance)",
        "lo": 100.0,
        "hi": 600.0
    },
    {
        "tab": "",
        "group": "KEY REPEAT",
        "key": "input.repeatRate",
        "label": "Repeat rate",
        "desc": "",
        "ctl": "step",
        "src": "settings.lua (input.repeat_rate)",
        "lo": 1.0,
        "hi": 100.0,
        "unit": "/s"
    },
    {
        "tab": "",
        "group": "KEY REPEAT",
        "key": "input.repeatDelay",
        "label": "Repeat delay",
        "desc": "",
        "ctl": "step",
        "src": "settings.lua (input.repeat_delay)",
        "lo": 100.0,
        "hi": 2000.0,
        "unit": "ms"
    }
];
