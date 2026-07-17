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
        "desc": "Extra layout kept loaded; pick a chord below to switch between the two",
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
        "desc": "Variant of the main layout, like Dvorak; the second layout stays plain",
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
        "desc": "Extra layout kept loaded; pick a chord below to switch between the two",
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
        "desc": "Raw xkb options, comma separated; the pickers above manage their own",
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
        "desc": "Starts the session with the keypad typing digits, not arrows",
        "ctl": "sw",
        "src": "settings.lua (input.numlock_by_default)"
    },
    {
        "tab": "",
        "group": "KEY REMAPS",
        "key": "input.kbOptions",
        "label": "Caps Lock",
        "desc": "Raw xkb options, comma separated; the pickers above manage their own",
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
        "desc": "Raw xkb options, comma separated; the pickers above manage their own",
        "ctl": "sw",
        "src": "settings.lua (input.kb_options)"
    },
    {
        "tab": "",
        "group": "KEY REMAPS",
        "key": "input.kbOptions",
        "label": "Compose key",
        "desc": "Raw xkb options, comma separated; the pickers above manage their own",
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
        "desc": "Raw xkb options, comma separated; the pickers above manage their own",
        "ctl": "text",
        "src": "settings.lua (input.kb_options)"
    },
    {
        "tab": "",
        "group": "KEY REMAPS",
        "key": "",
        "label": "Apply system-wide",
        "desc": "Result of the last apply; by default these keep their own keymap",
        "ctl": "action",
        "src": "vconsole.conf, via `localectl set-x11-keymap <kbLayout> \"\" <kbVariant> <kbOptions>`"
    },
    {
        "tab": "",
        "group": "KEY REMAPS",
        "key": "",
        "label": "Login screen and TTY keymap status",
        "desc": "Result of the last apply; by default these keep their own keymap",
        "ctl": "readout",
        "src": "shell"
    },
    {
        "tab": "",
        "group": "POINTER",
        "key": "input.sensitivity",
        "label": "Sensitivity",
        "desc": "Pointer speed offset; 0 is the device default, negative slows it down",
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
        "desc": "How window focus follows the pointer; Loose keeps typing where it was",
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
        "desc": "Flat ties pointer travel to hand travel; Adaptive speeds up quick moves",
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
        "desc": "Swaps the left and right mouse buttons",
        "ctl": "sw",
        "src": "settings.lua (input.left_handed)"
    },
    {
        "tab": "",
        "group": "POINTER",
        "key": "input.mouseNaturalScroll",
        "label": "Natural scroll",
        "desc": "The wheel drags the content, touchscreen style: roll up, page moves up",
        "ctl": "sw",
        "src": "settings.lua (input.natural_scroll)"
    },
    {
        "tab": "",
        "group": "POINTER",
        "key": "input.mouseScrollFactor",
        "label": "Scroll speed",
        "desc": "Multiplies each wheel notch; 1 is normal, 3 jumps three times as far",
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
        "desc": "Pressing the wheel inserts the last text you highlighted",
        "ctl": "sw",
        "src": "settings.lua"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.naturalScroll",
        "label": "Natural scroll",
        "desc": "Two-finger scrolling drags the content like a touchscreen",
        "ctl": "sw",
        "src": "settings.lua (input.touchpad.natural_scroll)"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.tapToClick",
        "label": "Tap to click",
        "desc": "A tap is a click: one finger left, two right, three middle",
        "ctl": "sw",
        "src": "settings.lua (input.touchpad.tap_to_click)"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.tapAndDrag",
        "label": "Tap and drag",
        "desc": "Tap, then keep the finger down to drag what you tapped",
        "ctl": "sw",
        "src": "settings.lua (input.touchpad.tap_and_drag)"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.disableWhileTyping",
        "label": "Disable while typing",
        "desc": "Ignores the touchpad while you type so the palm cannot move the cursor",
        "ctl": "sw",
        "src": "settings.lua (input.touchpad.disable_while_typing)"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.clickfinger",
        "label": "Click by finger count",
        "desc": "One-finger press clicks left, two right, three middle, ignoring position",
        "ctl": "sw",
        "src": "settings.lua (input.touchpad.clickfinger_behavior)"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.middleEmulation",
        "label": "Emulate middle click",
        "desc": "Pressing left and right together counts as a middle click",
        "ctl": "sw",
        "src": "settings.lua (input.touchpad.middle_button_emulation)"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.touchScrollFactor",
        "label": "Scroll speed",
        "desc": "Multiplies two-finger scroll distance; 1 matches finger travel",
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
        "desc": "A horizontal swipe slides to the next workspace; unlocks the rows below",
        "ctl": "sw",
        "src": "settings.lua"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.swipeFingers",
        "label": "Swipe fingers",
        "desc": "How many fingers count as a workspace swipe",
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
        "desc": "The workspace row follows your fingers, like dragging a sheet of paper",
        "ctl": "sw",
        "src": "settings.lua (gestures.workspace_swipe_invert)"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.swipeCreateNew",
        "label": "Swipe past the last workspace to add one",
        "desc": "Continuing past the end opens an empty workspace instead of stopping",
        "ctl": "sw",
        "src": "settings.lua (gestures.workspace_swipe_create_new)"
    },
    {
        "tab": "",
        "group": "TOUCHPAD",
        "key": "input.swipeDistance",
        "label": "Swipe distance",
        "desc": "Finger travel in pixels for a full switch; lower flips with less motion",
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
        "desc": "Characters per second while a key is held down",
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
        "desc": "Pause before a held key starts repeating",
        "ctl": "step",
        "src": "settings.lua (input.repeat_delay)",
        "lo": 100.0,
        "hi": 2000.0,
        "unit": "ms"
    }
];
