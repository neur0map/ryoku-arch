# Overwrite parts of the ryoku-menu with user-specific submenus.
# See $RYOKU_PATH/bin/ryoku-menu for functions that can be overwritten.
#
# WARNING: Overwritten functions will obviously not be updated when Ryoku changes.
#
# Example of minimal system menu:
#
# show_system_menu() {
#   case $(menu "System" "  Lock\n󰐥  Shutdown") in
#   *Lock*) ryoku-lock-screen ;;
#   *Shutdown*) ryoku-system-shutdown ;;
#   *) back_to show_main_menu ;;
#   esac
# }
#
# Example of overriding just the about menu action: (Using zsh instead of bash (default))
#
# show_about() {
#   exec ryoku-launch-or-focus-tui "zsh -c 'fastfetch; read -k 1'"
# }
