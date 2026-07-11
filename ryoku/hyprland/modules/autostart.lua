hl.on("hyprland.start", function()
    hl.exec_cmd("hyprctl setcursor Bibata-Modern-Ice 24")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme prefer-dark")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark")
    hl.exec_cmd("systemctl --user start hyprland-session.target")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("command -v ryoku-monitor >/dev/null 2>&1 && ryoku-monitor autoscale")
    hl.exec_cmd("command -v ryoku-gpu >/dev/null 2>&1 && ryoku-gpu persist")
    hl.exec_cmd("ryoku-shell daemon")
    hl.exec_cmd("command -v ryoku-idle >/dev/null 2>&1 && ryoku-idle start")
    hl.exec_cmd("command -v ryoku-leds >/dev/null 2>&1 && ryoku-leds apply")
    hl.exec_cmd("command -v ryoku-mic >/dev/null 2>&1 && ryoku-mic")
    -- Voxtype dictation: `ryoku-hub voxtype ensure` seeds a default config with
    -- the built-in hotkey off (the shell owns Super+` and the mic wave), installs
    -- the user service once, and starts it unless you turned dictation off in the
    -- Hub. The shell then drives it with `voxtype record` on the Super+` tap.
    hl.exec_cmd("command -v voxtype >/dev/null 2>&1 && command -v ryoku-hub >/dev/null 2>&1 && ryoku-hub voxtype ensure >/dev/null 2>&1")
    -- First-login welcome walkthrough: show the guided tour once, then mark it
    -- seen so it never returns. The flag lives in state (not config), so it needs
    -- no doctor reconciler; an flock guards a double fire. The tour window quits on
    -- finish or close, then the flag is written -- so it appears exactly once. exec
    -- is async, so the blocking `qs` here never holds up the rest of autostart.
    local welcome_state = (os.getenv("XDG_STATE_HOME") or (os.getenv("HOME") .. "/.local/state")) .. "/ryoku"
    hl.exec_cmd("[ -e '" .. welcome_state .. "/welcome-seen' ] || { flock -n -o /tmp/ryoku-welcome.lock qs -c welcome; mkdir -p '" .. welcome_state .. "'; touch '" .. welcome_state .. "/welcome-seen'; }")
end)
