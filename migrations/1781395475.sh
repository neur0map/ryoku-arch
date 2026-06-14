echo "Move audio visualiser/spectrum and volume-feedback settings into the typed shell config"

# Stage 1 consolidation: the remaining audio media keys (bar audio-visualiser style,
# spectrum mirroring/frame-rate, MPRIS blacklist, volume-change feedback) now live in
# typed GlobalConfig under `services` (~/.config/ryoku/shell.json). Copy the values the
# user already set from the legacy settings-gui audio domain. Only the media keys move
# here; volume step/overdrive/player were reconciled separately to the existing
# services.audioIncrement/maxVolume/defaultPlayer keys.
src="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/settings-gui/settings.json"
dst="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/shell.json"

if ryoku-cmd-missing jq; then
  echo "  jq missing; skipping audio media config migration"
  exit 0
fi

[[ -f $src ]] || exit 0
mkdir -p "$(dirname "$dst")"
[[ -f $dst ]] || printf '{}\n' >"$dst"

tmp="$(mktemp)"
if jq --slurpfile s "$src" '
  ($s[0].audio // {}) as $a
  | .services = ((.services // {})
      + ($a
         | {visualizerType, spectrumMirrored, spectrumFrameRate, mprisBlacklist, volumeFeedback, volumeFeedbackSoundFile}
         | with_entries(select(.value != null))))
' "$dst" >"$tmp"; then
  mv "$tmp" "$dst"
else
  rm -f "$tmp"
fi

if ryoku-cmd-present systemctl; then
  systemctl --user restart ryoku-shell.service >/dev/null 2>&1 || true
fi
