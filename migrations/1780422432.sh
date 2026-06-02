echo "Install gnome-calendar so the shell calendar date-click works on existing installs"

# The shell's CalendarMonthCard opens `gnome-calendar --date` on a date click,
# gated on ProgramCheckerService.gnomeCalendarAvailable. gnome-calendar was wired
# but never shipped, so the action was a silent no-op. It is now in
# install/ryoku-base.packages for fresh installs; install it on existing ones.
ryoku-pkg-add gnome-calendar
