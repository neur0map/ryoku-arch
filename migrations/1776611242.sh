echo "Install socat so we can reactivate internal display when external display is removed"

ryoku-pkg-add socat
uwsm-app -- ryoku-hyprland-monitor-watch &
