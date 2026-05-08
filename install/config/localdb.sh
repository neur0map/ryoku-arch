# Update localdb so that locate will find everything installed
if ryoku-cmd-missing updatedb; then
  echo "plocate is not installed; skipping localdb update."
  exit 0
fi

sudo updatedb
