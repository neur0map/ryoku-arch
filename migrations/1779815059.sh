echo "Retarget audio mixer and resume listener services to the user default target"

if [[ -x $RYOKU_PATH/install/config/ryoku-audio-restore-mixers.sh ]]; then
  "$RYOKU_PATH/install/config/ryoku-audio-restore-mixers.sh"
fi

if [[ -x $RYOKU_PATH/install/config/ryoku-resume-listener.sh ]]; then
  "$RYOKU_PATH/install/config/ryoku-resume-listener.sh"
fi

if ryoku-cmd-present ryoku-audio-restore-mixers; then
  ryoku-audio-restore-mixers || true
elif [[ -x $RYOKU_PATH/bin/ryoku-audio-restore-mixers ]]; then
  "$RYOKU_PATH/bin/ryoku-audio-restore-mixers" || true
fi
