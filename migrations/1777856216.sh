echo "Install Ryoku resume listener (user-level systemd unit watching logind PrepareForSleep)"

if [[ -x $RYOKU_PATH/install/config/ryoku-resume-listener.sh ]]; then
  "$RYOKU_PATH/install/config/ryoku-resume-listener.sh"
fi

systemctl --user daemon-reload >/dev/null 2>&1 || true
