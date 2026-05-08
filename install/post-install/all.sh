run_logged $RYOKU_INSTALL/post-install/hibernation.sh
run_logged $RYOKU_INSTALL/post-install/pacman.sh
run_logged $RYOKU_INSTALL/post-install/ensure-shell-deployment.sh
source $RYOKU_INSTALL/post-install/allow-reboot.sh
source $RYOKU_INSTALL/post-install/finished.sh
