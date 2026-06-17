# shellcheck shell=bash
# Start the Ryoku installer automatically, but only on the first virtual console.
# Other VTs and the serial console (ttyS0) stay a plain root shell so you can
# recover or run the backend by hand.
if [[ "$(tty)" == /dev/tty1 ]]; then
  /usr/local/bin/ryoku-installer-session
fi
