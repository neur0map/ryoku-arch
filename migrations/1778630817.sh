echo "Remove Ryoku browser theme policy files"

policy_files=(
  /etc/chromium/policies/managed/color.json
  /etc/chromium/policies/managed/ii-theme.json
  /etc/brave/policies/managed/color.json
  /etc/brave/policies/managed/ii-theme.json
  /etc/opt/chrome/policies/managed/ii-theme.json
)

policy_dirs=(
  /etc/chromium/policies/managed
  /etc/brave/policies/managed
  /etc/opt/chrome/policies/managed
)

remove_path() {
  local path="$1"

  if [[ ! -e $path ]]; then
    return 0
  fi

  if [[ -w $path || -w $(dirname "$path") ]]; then
    rm -f "$path" 2>/dev/null || true
  else
    sudo rm -f "$path" 2>/dev/null || true
  fi
}

for policy_file in "${policy_files[@]}"; do
  remove_path "$policy_file"
done

for policy_dir in "${policy_dirs[@]}"; do
  [[ -d $policy_dir ]] || continue

  if [[ -z $(find "$policy_dir" -mindepth 1 -print -quit 2>/dev/null) ]]; then
    if [[ -w $(dirname "$policy_dir") ]]; then
      rmdir "$policy_dir" 2>/dev/null || true
    else
      sudo rmdir "$policy_dir" 2>/dev/null || true
    fi
  else
    sudo chmod 0755 "$policy_dir" 2>/dev/null || true
  fi
done
