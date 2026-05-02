#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)/lib/runtime-env.sh"

INIR_REPO="${RYOKU_INIR_REPO:-https://github.com/snowarch/iNiR.git}"
INIR_PATH="${RYOKU_INIR_PATH:-$HOME/.local/share/inir}"
INIR_SOURCE="${RYOKU_INIR_SOURCE:-}"
INIR_REQUIRE_LOCAL_SOURCE="${RYOKU_INIR_REQUIRE_LOCAL_SOURCE:-0}"

if [[ -n ${RYOKU_CHROOT_INSTALL:-} ]]; then
  INIR_REQUIRE_LOCAL_SOURCE=1
fi

setup_env=()
if [[ -n ${RYOKU_CHROOT_INSTALL:-} && -d /var/cache/ryoku/uv ]]; then
  setup_env+=(
    UV_CACHE_DIR=/var/cache/ryoku/uv
    UV_OFFLINE=1
    UV_PYTHON_DOWNLOADS=never
  )
fi

if [[ -d $INIR_PATH/.git ]]; then
  if [[ ${RYOKU_INIR_UPDATE:-0} == "1" ]]; then
    git -C "$INIR_PATH" pull --ff-only
  fi
else
  if [[ -z $INIR_SOURCE ]]; then
    for candidate in \
      "$RYOKU_PATH/vendor/inir" \
      "/root/inir" \
      "/opt/ryoku/inir"
    do
      if [[ -d $candidate/.git ]]; then
        INIR_SOURCE="$candidate"
        break
      fi
    done
  fi

  if [[ -z $INIR_SOURCE ]]; then
    if [[ $INIR_REQUIRE_LOCAL_SOURCE == "1" ]]; then
      echo "install/config/inir.sh: missing bundled Ryoku shell checkout for offline install" >&2
      echo "Expected one of: $INIR_PATH, $RYOKU_PATH/vendor/inir, /root/inir, /opt/ryoku/inir" >&2
      exit 1
    fi

    INIR_SOURCE="$INIR_REPO"
  fi

  if [[ -e $INIR_PATH ]]; then
    echo "install/config/inir.sh: $INIR_PATH exists but is not a git checkout" >&2
    exit 1
  elif [[ -d $INIR_SOURCE/.git ]]; then
    mkdir -p "$(dirname "$INIR_PATH")"
    cp -a "$INIR_SOURCE" "$INIR_PATH"
  else
    mkdir -p "$(dirname "$INIR_PATH")"
    git clone "$INIR_SOURCE" "$INIR_PATH"
  fi
fi

(
  cd "$INIR_PATH"
  if (( ${#setup_env[@]} > 0 )); then
    env "${setup_env[@]}" ./setup install -y --skip-deps --skip-sysupdate
  else
    ./setup install -y --skip-deps --skip-sysupdate
  fi
)

"$RYOKU_PATH/install/config/ryoku-shell-branding.sh"

inir_launcher="$HOME/.local/bin/inir"
if [[ -x $inir_launcher ]]; then
  "$inir_launcher" service enable niri >/dev/null 2>&1 || true
elif ryoku-cmd-present inir; then
  inir service enable niri >/dev/null 2>&1 || true
fi

inir_service="$HOME/.config/systemd/user/inir.service"
inir_wants_dir="$HOME/.config/systemd/user/niri.service.wants"
if [[ -f $inir_service ]]; then
  mkdir -p "$inir_wants_dir"
  ln -sf "$inir_service" "$inir_wants_dir/inir.service"
  systemctl --user daemon-reload >/dev/null 2>&1 || true
fi
