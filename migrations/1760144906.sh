echo "Change ryoku-screenrecord to use gpu-screen-recorder"
ryoku-pkg-drop wf-recorder wl-screenrec

# Add slurp in case it hadn't been picked up from an old migration
ryoku-pkg-add slurp gpu-screen-recorder
