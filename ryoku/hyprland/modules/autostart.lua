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
    hl.exec_cmd("command -v ryoku-rashin >/dev/null 2>&1 && ryoku-rashin serve --if-enabled")
    hl.exec_cmd("command -v ryoku-leds >/dev/null 2>&1 && ryoku-leds apply")
    hl.exec_cmd("command -v ryoku-mic >/dev/null 2>&1 && ryoku-mic")
    -- Handy starts hidden into the tray; wait for the shell's StatusNotifierWatcher
    -- first, or at boot Handy outraces it, finds no tray to hide in, and shows its
    -- window. The pill's tray filters its item out by title.
    hl.exec_cmd("command -v handy >/dev/null 2>&1 && { for _ in $(seq 40); do busctl --user list 2>/dev/null | grep -q org.kde.StatusNotifierWatcher && break; sleep 0.25; done; handy --start-hidden; }")
end)
