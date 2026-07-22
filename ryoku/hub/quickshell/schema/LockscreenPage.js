.pragma library

// LockscreenPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "OTHER",
        "key": "",
        "label": "Lock skin",
        "desc": "Reskins the lock and sign-in screens, asks for your password to apply",
        "ctl": "chips",
        "src": "99-ryoku.conf (contents `[Theme]\\nCurrent=ryoku\\n`). Paths overridable by env: RYOKU_SDDM_THEMES_DIR, RYOKU_SDDM_CONF, RYOKU_QYLOCK_THEMES.",
        "opts": [
            "clockwork/orbital",
            "clockwork/tape",
            "<dynamic>",
            "last-of-us",
            "windows_7",
            "pixel-*",
            "R1999*",
            "<any"
        ]
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "",
        "label": "At sign-in (keyring)",
        "desc": "How the GNOME keyring unlocks your saved passwords and secrets at sign-in: unlock on login, never ask, or ask each time. keyring secrets passwords unlock sign-in",
        "ctl": "chips",
        "src": "~/.config/ryoku/keyring.json (mode) and /etc/pam.d/sddm (pam_gnome_keyring). Managed by `ryoku keyring set`; $RYOKU_PAM_FILE overrides the PAM path for tests.",
        "opts": [
            "unlock-on-login",
            "never-ask",
            "ask"
        ]
    }
];
