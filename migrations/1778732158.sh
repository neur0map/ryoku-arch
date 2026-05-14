echo "Refresh qylock previews and login-screen settings"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
QYLOCK_DIR="$HOME/.local/share/qylock"
PREVIEW_HELPER="$RYOKU_PATH/bin/ryoku-refresh-qylock-previews"
LOGIN_SCREEN_QML="$RYOKU_PATH/shell/modules/settings/LoginScreenConfig.qml"

if [[ -x $PREVIEW_HELPER && -d $QYLOCK_DIR/themes ]]; then
  "$PREVIEW_HELPER" "$QYLOCK_DIR" || true
fi

refresh_login_screen_qml() {
  local target="$1"
  local target_dir

  [[ -f $LOGIN_SCREEN_QML ]] || return 0
  target_dir="$(dirname "$target")"
  [[ -d $target_dir ]] || return 0
  if [[ ! -f $target ]] || ! cmp -s "$LOGIN_SCREEN_QML" "$target"; then
    cp -f "$LOGIN_SCREEN_QML" "$target"
  fi
}

refresh_login_screen_qml "$CONFIG_HOME/quickshell/ryoku-shell/modules/settings/LoginScreenConfig.qml"
refresh_login_screen_qml "$HOME/.local/share/ryoku-shell/modules/settings/LoginScreenConfig.qml"
refresh_login_screen_qml "$HOME/.local/share/ryoku/shell/modules/settings/LoginScreenConfig.qml"
