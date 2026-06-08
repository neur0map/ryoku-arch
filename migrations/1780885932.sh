echo "Ensure the Ryoku resume listener is enabled and running in the live session"

if [[ -x $RYOKU_PATH/install/config/ryoku-resume-listener.sh ]]; then
  "$RYOKU_PATH/install/config/ryoku-resume-listener.sh"
fi
