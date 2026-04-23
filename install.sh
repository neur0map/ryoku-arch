#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -eEo pipefail

# Load the shared runtime contract for installer paths and compatibility aliases.
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/lib/runtime-env.sh"

# Install
source "$RYOKU_INSTALL/helpers/all.sh"
source "$RYOKU_INSTALL/preflight/all.sh"
source "$RYOKU_INSTALL/packaging/all.sh"
source "$RYOKU_INSTALL/config/all.sh"
source "$RYOKU_INSTALL/login/all.sh"
source "$RYOKU_INSTALL/post-install/all.sh"
