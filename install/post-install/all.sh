run_logged $RYOKU_INSTALL/post-install/hibernation.sh
run_logged $RYOKU_INSTALL/post-install/pacman.sh
# Re-run the same shell-deployment safety net we did at preflight, so any
# install stage that stomped paths (e.g. shell.sh's setup install) gets
# patched up before reboot.
run_logged $RYOKU_INSTALL/preflight/ensure-shell-deployment.sh
source $RYOKU_INSTALL/post-install/allow-reboot.sh
source $RYOKU_INSTALL/post-install/finished.sh
