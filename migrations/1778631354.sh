echo "Harden leftover browser policy directories"

policy_dirs=(
  /etc/chromium/policies/managed
  /etc/brave/policies/managed
  /etc/opt/chrome/policies/managed
)

try_root() {
  if "$@" 2>/dev/null; then
    return 0
  fi

  sudo "$@" 2>/dev/null || true
}

for policy_dir in "${policy_dirs[@]}"; do
  [[ -d $policy_dir ]] || continue

  if [[ -z $(find "$policy_dir" -mindepth 1 -print -quit 2>/dev/null) ]]; then
    try_root rmdir "$policy_dir"
  fi

  [[ -d $policy_dir ]] || continue
  try_root chmod 0755 "$policy_dir"
done
