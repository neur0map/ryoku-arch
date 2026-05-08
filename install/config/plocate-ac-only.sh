if ryoku-cmd-missing updatedb || [[ ! -f /usr/lib/systemd/system/plocate-updatedb.service ]]; then
  echo "plocate is not installed; skipping AC-only indexer config."
  exit 0
fi

sudo install -d /etc/systemd/system/plocate-updatedb.service.d
printf '%s\n' '[Unit]' 'ConditionACPower=true' | sudo tee /etc/systemd/system/plocate-updatedb.service.d/ac-only.conf >/dev/null
sudo systemctl daemon-reload
