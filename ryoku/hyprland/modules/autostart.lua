hl.on("hyprland.start", function()
    -- Start the GNOME keyring's secrets + pkcs11 agents before anything that
    -- might ask for a stored secret. Idempotent: if PAM already started it at
    -- login (unlock-on-login mode), this just re-prints its env and exits.
    hl.exec_cmd("gnome-keyring-daemon --start --components=secrets,pkcs11")
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface font-name 'Space Grotesk 11'")
    -- Folder icons follow the wallpaper accent: ryoku-cmd-folders builds a small
    -- Papirus-Dark overlay (~/.local/share/icons/ryoku-folders) tinted to the
    -- palette, then we select it. Rebuilt on every palette change by the shell.
    hl.exec_cmd("command -v ryoku-cmd-folders >/dev/null 2>&1 && ryoku-cmd-folders && gsettings set org.gnome.desktop.interface icon-theme ryoku-folders")
    -- Import the Wayland/session env into the systemd --user manager and the
    -- D-Bus activation environment BEFORE the session target starts. Without
    -- it, a user service gated on that env fails: hyprpolkitagent declares
    -- ConditionEnvironment=WAYLAND_DISPLAY, so a bare `systemctl --user start`
    -- never satisfied the condition and the polkit agent came up failed (the
    -- doctor "hyprpolkitagent.service failed" out of the box).
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE XDG_SESSION_TYPE")
    hl.exec_cmd("systemctl --user start hyprland-session.target")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("command -v ryoku-monitor >/dev/null 2>&1 && ryoku-monitor autoscale")
    -- Keyring default: no app ever prompts for a keyring password out of the box.
    -- `keyring init` records the mode once and seeds a blank passwordless default
    -- keyring for never-ask (idempotent; a no-op once a mode is chosen). Best
    -- effort: an old ryoku without the subcommand just fails silently here.
    hl.exec_cmd("command -v ryoku >/dev/null 2>&1 && ryoku keyring init")
    hl.exec_cmd("command -v ryoku-gpu >/dev/null 2>&1 && ryoku-gpu persist")
    hl.exec_cmd("ryoku-shell daemon")
    hl.exec_cmd("command -v ryoku-idle >/dev/null 2>&1 && ryoku-idle start")
    hl.exec_cmd("command -v ryoku-clamshell >/dev/null 2>&1 && ryoku-clamshell daemon")
    hl.exec_cmd("command -v ryoku-leds >/dev/null 2>&1 && ryoku-leds apply")
    hl.exec_cmd("command -v ryoku-mic >/dev/null 2>&1 && ryoku-mic")
    hl.exec_cmd("command -v ryoku-eq >/dev/null 2>&1 && ryoku-eq apply")
    -- Booted into a btrfs snapshot from the Limine menu: offer the one-click
    -- restore. limine-snapper-sync ships this as an XDG autostart entry, which
    -- Hyprland never runs (no autostart manager), so start it here; on a normal
    -- boot it detects no snapshot and exits silently.
    hl.exec_cmd("command -v limine-snapper-restore >/dev/null 2>&1 && limine-snapper-restore --notify")
    -- Voxtype dictation: `ryoku-hub voxtype ensure` seeds a default config with
    -- the built-in hotkey off (the shell owns Super+` and the mic wave), installs
    -- the user service once, and starts it unless you turned dictation off in the
    -- Hub. The shell then drives it with `voxtype record` on the Super+` tap.
    hl.exec_cmd("command -v voxtype >/dev/null 2>&1 && command -v ryoku-hub >/dev/null 2>&1 && ryoku-hub voxtype ensure >/dev/null 2>&1")
    -- AI UI translation: seed ~/.config/ryoku/i18n-llm.json (empty key) so the
    -- file exists for the user to paste an API key into; idempotent, a no-op if
    -- present. The Hub's Language > "Generate with AI" then reads it.
    hl.exec_cmd("command -v ryoku-i18n >/dev/null 2>&1 && ryoku-i18n ensure >/dev/null 2>&1")
    -- First-login welcome walkthrough: show the guided tour once, then mark it
    -- seen so it never returns. The flag lives in state (not config), so it needs
    -- no doctor reconciler. The seen-check lives in Lua because Hyprland's exec
    -- reads a leading [...] as its window-rules prefix: the old `[ -e flag ]`
    -- shell guard was eaten as a rule block, sh got a line starting at `||`, and
    -- the tour never launched on any install. The flock still guards a double
    -- fire, and the flag is written only if qs actually ran the tour (`&&`), so a
    -- first-boot launch failure retries next login instead of marking it seen
    -- forever. exec is async, so the blocking `qs` never holds up autostart.
    local welcome_state = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/ryoku"
    local seen = io.open(welcome_state .. "/welcome-seen", "r")
    if seen then
        seen:close()
    else
        hl.exec_cmd("flock -n \"${XDG_RUNTIME_DIR:-/tmp}/ryoku-welcome.lock\" qs -c welcome && mkdir -p '" .. welcome_state .. "' && touch '" .. welcome_state .. "/welcome-seen'")
    end
end)
