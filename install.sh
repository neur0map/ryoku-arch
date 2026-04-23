#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -eEo pipefail

# Pin the runtime contract to this checkout so the installer runs against the
# repo it was invoked from, not whatever tree happens to live at ~/.local/share.
RYOKU_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export RYOKU_PATH
source "$RYOKU_PATH/lib/runtime-env.sh"

# Install
source "$RYOKU_INSTALL/helpers/all.sh"
source "$RYOKU_INSTALL/preflight/all.sh"
source "$RYOKU_INSTALL/packaging/all.sh"
source "$RYOKU_INSTALL/config/all.sh"
source "$RYOKU_INSTALL/login/all.sh"
source "$RYOKU_INSTALL/post-install/all.sh"
