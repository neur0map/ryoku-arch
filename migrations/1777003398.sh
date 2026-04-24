echo "Refresh user uwsm env/default to drop legacy omarchy references"

UWSM_ENV="$HOME/.config/uwsm/env"
UWSM_DEFAULT="$HOME/.config/uwsm/default"

# Stale omarchy-cmd-present call in uwsm/env errors at session start
# and (worse) prevents the mise shim activation. Rewrite the line in
# place so the user's uwsm/env stops failing when sourced.
if [[ -f $UWSM_ENV ]] && grep -q '^omarchy-cmd-present ' "$UWSM_ENV"; then
  sed -i 's/^omarchy-cmd-present /ryoku-cmd-present /' "$UWSM_ENV"
  echo "  patched $UWSM_ENV: omarchy-cmd-present -> ryoku-cmd-present"
fi

# Legacy commented env var examples in uwsm/default. Harmless, but tidy.
if [[ -f $UWSM_DEFAULT ]]; then
  sed -i 's/OMARCHY_SCREENSHOT_DIR/RYOKU_SCREENSHOT_DIR/g;
          s/OMARCHY_SCREENRECORD_DIR/RYOKU_SCREENRECORD_DIR/g' "$UWSM_DEFAULT"
fi

# Push the session PATH into the systemd user manager so processes spawned
# via 'uwsm-app -- <cmd>' (which goes through systemd-run) inherit the
# Ryoku bin directory. Without this, exec-once entries that go through
# uwsm-app may hit 'command not found' for Ryoku commands even though the
# interactive shell resolves them fine.
if [[ -f $UWSM_ENV ]] && ! grep -q 'systemctl --user import-environment PATH' "$UWSM_ENV"; then
  cat >>"$UWSM_ENV" <<'EOF'

# Propagate the session PATH (with $RYOKU_PATH/bin) to the systemd user
# manager so processes started via uwsm-app / systemd-run inherit it.
systemctl --user import-environment PATH 2>/dev/null || true
EOF
  echo "  appended systemd user PATH import to $UWSM_ENV"
fi

# Ensure the RUNNING systemd user manager also has PATH now - so if the
# user does not reboot they still get working uwsm-app child processes.
systemctl --user import-environment PATH 2>/dev/null || true
