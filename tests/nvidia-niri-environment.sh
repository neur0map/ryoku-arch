#!/bin/bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

link_cmd() {
  local cmd="$1"
  local dest_dir="$2"

  ln -sf "$(command -v "$cmd")" "$dest_dir/$cmd"
}

assert_nvidia_env_is_merged_into_existing_niri_environment() {
  local temp_dir home_dir bin_dir config_file niri_config

  temp_dir=$(mktemp -d)
  home_dir="$temp_dir/home"
  bin_dir="$temp_dir/bin"
  config_file="$home_dir/.config/niri/config.d/40-environment.kdl"
  niri_config="$home_dir/.config/niri/config.kdl"

  mkdir -p "$(dirname "$config_file")" "$bin_dir"

  cat > "$niri_config" <<'EOF'
include "config.d/40-environment.kdl"
EOF

  cat > "$config_file" <<'EOF'
environment {
    XDG_CURRENT_DESKTOP "niri"
}
EOF

  for cmd in grep head mkdir sed; do
    link_cmd "$cmd" "$bin_dir"
  done

  cat > "$bin_dir/lspci" <<'EOF'
#!/bin/bash
echo "01:00.0 VGA compatible controller: NVIDIA Corporation GeForce RTX 3060"
EOF

  cat > "$bin_dir/pacman" <<'EOF'
#!/bin/bash
if [[ $1 == "-Qqs" ]]; then
  echo "linux"
fi
EOF

  cat > "$bin_dir/ryoku-pkg-add" <<'EOF'
#!/bin/bash
exit 0
EOF

  cat > "$bin_dir/sudo" <<'EOF'
#!/bin/bash
cat >/dev/null
exit 0
EOF

  chmod +x "$bin_dir/lspci" "$bin_dir/pacman" "$bin_dir/ryoku-pkg-add" "$bin_dir/sudo"

  HOME="$home_dir" PATH="$bin_dir:$PATH" \
    /bin/bash "$ROOT_DIR/install/config/hardware/nvidia.sh"

  if (( $(grep -c '^[[:space:]]*environment[[:space:]]*{' "$config_file") != 1 )); then
    cat "$config_file" >&2
    rm -rf "$temp_dir"
    fail "NVIDIA setup should not append a duplicate Niri environment block"
  fi

  grep -q '^[[:space:]]*NVD_BACKEND "direct"' "$config_file" \
    || fail "NVIDIA setup should set direct backend for Turing+ GPUs"
  grep -q '^[[:space:]]*LIBVA_DRIVER_NAME "nvidia"' "$config_file" \
    || fail "NVIDIA setup should set LIBVA driver for Turing+ GPUs"
  grep -q '^[[:space:]]*__GLX_VENDOR_LIBRARY_NAME "nvidia"' "$config_file" \
    || fail "NVIDIA setup should set GLX vendor"

  if grep -q '^#' "$config_file"; then
    cat "$config_file" >&2
    rm -rf "$temp_dir"
    fail "Niri KDL should use // comments, not shell-style # comments"
  fi

  if command -v niri >/dev/null 2>&1; then
    XDG_CONFIG_HOME="$home_dir/.config" niri validate -c "$niri_config" >/dev/null \
      || fail "NVIDIA-mutated Niri config should validate"
  fi

  rm -rf "$temp_dir"
}

assert_nvidia_env_is_merged_into_existing_niri_environment

echo "PASS: NVIDIA Niri environment tests"
