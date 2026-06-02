echo "Regenerate qylock lockscreen previews so existing installs show theme previews"

# The preview generator now handles nested theme variants (clockwork/orbital,
# clockwork/tape) and color-type themes (a solid-colour swatch), so the Settings
# lockscreen gallery shows previews instead of "No preview" for already-installed
# themes. The Settings Refresh button now also fetches the full upstream qylock
# collection (>2 themes); this migration just repairs previews for the bundled
# themes on machines installed before the fix.
qylock_dir="$HOME/.local/share/qylock"
if [[ -d $qylock_dir/themes ]] && command -v ryoku-refresh-qylock-previews >/dev/null 2>&1; then
  ryoku-refresh-qylock-previews "$qylock_dir" >/dev/null 2>&1 || true
fi
