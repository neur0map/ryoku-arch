#!/bin/bash

# Resolve the active Ryoku repo path. RYOKU_LEGACY_PATH is a last-ditch
# fallback for systems that still have the pre-rename ~/.local/share/omarchy
# checkout; it lets tools keep working on an unmigrated box until the
# share-path migration converges the directory layout.
export RYOKU_PATH_DEFAULT="$HOME/.local/share/ryoku"
export RYOKU_LEGACY_PATH="$HOME/.local/share/omarchy"
export RYOKU_STATE_PATH="${RYOKU_STATE_PATH:-$HOME/.local/state/ryoku}"
export RYOKU_CONFIG_PATH="${RYOKU_CONFIG_PATH:-$HOME/.config/ryoku}"

if [[ -n ${RYOKU_PATH:-} ]]; then
  export RYOKU_PATH
elif [[ -e $RYOKU_PATH_DEFAULT ]]; then
  export RYOKU_PATH="$RYOKU_PATH_DEFAULT"
else
  export RYOKU_PATH="$RYOKU_LEGACY_PATH"
fi

export RYOKU_INSTALL="${RYOKU_INSTALL:-$RYOKU_PATH/install}"
export RYOKU_INSTALL_LOG_FILE="${RYOKU_INSTALL_LOG_FILE:-/var/log/ryoku-install.log}"

case ":$PATH:" in
  *":$RYOKU_PATH/bin:"*) ;;
  *) export PATH="$RYOKU_PATH/bin:$PATH" ;;
esac
