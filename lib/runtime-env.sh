#!/bin/bash

# Resolve the active Ryoku repo path with a legacy fallback during the rename.
export RYOKU_PATH_DEFAULT="$HOME/.local/share/ryoku"
export RYOKU_LEGACY_PATH="$HOME/.local/share/omarchy"
export RYOKU_STATE_PATH="${RYOKU_STATE_PATH:-$HOME/.local/state/ryoku}"
export RYOKU_CONFIG_PATH="${RYOKU_CONFIG_PATH:-$HOME/.config/ryoku}"

if [[ -e $RYOKU_PATH_DEFAULT ]]; then
  export RYOKU_PATH="$RYOKU_PATH_DEFAULT"
else
  export RYOKU_PATH="${RYOKU_PATH:-$RYOKU_LEGACY_PATH}"
fi

export RYOKU_INSTALL="${RYOKU_INSTALL:-$RYOKU_PATH/install}"
export RYOKU_INSTALL_LOG_FILE="${RYOKU_INSTALL_LOG_FILE:-/var/log/ryoku-install.log}"

# Keep installer compatibility until downstream scripts stop reading OMARCHY_*.
export OMARCHY_PATH="$RYOKU_PATH"
export OMARCHY_INSTALL="${OMARCHY_INSTALL:-$RYOKU_INSTALL}"
export OMARCHY_INSTALL_LOG_FILE="${OMARCHY_INSTALL_LOG_FILE:-$RYOKU_INSTALL_LOG_FILE}"

case ":$PATH:" in
  *":$RYOKU_PATH/bin:"*) ;;
  *) export PATH="$RYOKU_PATH/bin:$PATH" ;;
esac
