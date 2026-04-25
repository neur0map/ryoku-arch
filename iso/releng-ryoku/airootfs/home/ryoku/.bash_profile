#
# Ryoku live ISO: auto-launch Hyprland on tty1 first login.
# Manual login on other ttys drops to a regular shell.
#
[[ -f ~/.bashrc ]] && . ~/.bashrc

if [[ -z "$WAYLAND_DISPLAY" && "$(tty)" == "/dev/tty1" ]]; then
  export XDG_RUNTIME_DIR="/run/user/$UID"
  mkdir -p "$XDG_RUNTIME_DIR"
  exec Hyprland 2> ~/.hyprland.log
fi
