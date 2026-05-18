#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_dir="$(mktemp -d)"

cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"

  [[ -f $ROOT_DIR/$path ]] || fail "missing $path"
}

assert_contains() {
  local path="$1"
  local needle="$2"

  grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should contain: $needle"
}

assert_not_contains() {
  local path="$1"
  local needle="$2"

  ! grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should not contain: $needle"
}

assert_json_value() {
  local query="$1"
  local expected="$2"
  local actual

  actual="$(jq -r "$query" "$ROOT_DIR/shell/defaults/config.json")"
  [[ $actual == "$expected" ]] || fail "$query should be $expected, got $actual"
}

assert_generated_contains() {
  local path="$1"
  local needle="$2"

  grep -qF "$needle" "$path" || fail "$path should contain: $needle"
}

assert_generated_not_contains() {
  local path="$1"
  local needle="$2"

  ! grep -qF "$needle" "$path" || fail "$path should not contain: $needle"
}

qml_cava_schema="$(
  awk '
    /property JsonObject cava: JsonObject/ { in_cava=1 }
    in_cava { print }
    in_cava && /^                }/ { exit }
  ' "$ROOT_DIR/shell/modules/common/Config.qml"
)"

old_prefix="i""nir"
old_brand="i""NiR"
old_owner="snow""arch"

write_scope=(
  shell/defaults/config.json
  shell/modules/background/widgets/visualizer/VisualizerWidget.qml
  shell/modules/common/Config.qml
  shell/modules/common/widgets/CavaProcess.qml
  shell/modules/common/widgets/ConfigSelectionArray.qml
  shell/modules/common/widgets/WaveVisualizer.qml
  shell/modules/mediaControls/presets/AlbumArtPlayer.qml
  shell/modules/mediaControls/presets/ClassicPlayer.qml
  shell/modules/mediaControls/presets/CompactPlayer.qml
  shell/modules/mediaControls/presets/FullPlayer.qml
  shell/modules/mediaControls/presets/MinimalPlayer.qml
  shell/modules/mediaControls/presets/VisualizerPlayer.qml
  shell/modules/settings/AdvancedConfig.qml
  shell/modules/settings/BackgroundConfig.qml
  shell/modules/settings/DesktopWidgetsConfig.qml
  shell/modules/settings/ToolsConfig.qml
  shell/modules/waffle/settings/pages/WThemesPage.qml
  shell/scripts/cava/extract_cover_colors.py
  shell/scripts/cava/generate_config.sh
  shell/scripts/colors/modules/90-cava.sh
  shell/scripts/colors/targets/cava.json
)

for path in "${write_scope[@]}"; do
  assert_file "$path"
done

assert_json_value '.appearance.wallpaperTheming.enableCava' "false"
assert_json_value '.appearance.cava.sensitivity' "100"
assert_json_value '.appearance.cava.bars' "0"
assert_json_value '.appearance.cava.framerate' "60"
assert_json_value '.appearance.cava.stereo' "true"
assert_json_value '.appearance.cava.waveOpacity' "30"
assert_json_value '.background.widgets.mediaControls.visualizerType' "wave"
assert_json_value '.background.widgets.mediaControls.visualizerPosition' "bottom"
assert_json_value '.background.widgets.visualizer.vizType' "bars"
assert_json_value '.background.widgets.visualizer.waveOpacity' "-1"

for removed_key in colorSource gradientCount foreground background barWidth barSpacing; do
  assert_json_value ".appearance.cava | has(\"$removed_key\")" "false"
  assert_not_contains "shell/modules/settings/AdvancedConfig.qml" "appearance.cava.$removed_key"
  ! grep -qF "$removed_key" <<< "$qml_cava_schema" || fail "Config.qml cava schema should not contain $removed_key"
done

assert_contains "shell/modules/common/Config.qml" "property bool enableCava: false"
assert_contains "shell/modules/common/Config.qml" "property JsonObject cava: JsonObject"
assert_contains "shell/modules/common/Config.qml" "property int sensitivity: 100"
assert_contains "shell/modules/common/Config.qml" "property int bars: 0"
assert_contains "shell/modules/common/Config.qml" "property int framerate: 60"
assert_contains "shell/modules/common/Config.qml" "property bool stereo: true"
assert_contains "shell/modules/common/Config.qml" "property int waveOpacity: 30"
assert_contains "shell/modules/common/Config.qml" "property string visualizerType: \"wave\""
assert_contains "shell/modules/common/Config.qml" "property string visualizerPosition: \"bottom\""
assert_contains "shell/modules/common/Config.qml" "property string vizType: \"bars\""
assert_contains "shell/modules/common/Config.qml" "property int waveOpacity: -1"

assert_contains "shell/modules/common/widgets/CavaProcess.qml" "readonly property int cfgFramerate"
assert_contains "shell/modules/common/widgets/CavaProcess.qml" "readonly property int cfgSensitivity"
assert_contains "shell/modules/common/widgets/CavaProcess.qml" "readonly property int cfgBars"
assert_contains "shell/modules/common/widgets/CavaProcess.qml" "readonly property bool cfgStereo"
assert_contains "shell/modules/common/widgets/CavaProcess.qml" "property bool _pendingRestart: false"
assert_contains "shell/modules/common/widgets/CavaProcess.qml" "id: configRestart"
assert_contains "shell/modules/common/widgets/CavaProcess.qml" "onCfgFramerateChanged: if (active) configRestart.restart()"
assert_contains "shell/modules/common/widgets/CavaProcess.qml" "String(root.cfgFramerate)"
assert_contains "shell/modules/common/widgets/CavaProcess.qml" "String(root.cfgSensitivity)"
assert_contains "shell/modules/common/widgets/CavaProcess.qml" "String(root.effectiveBars)"
assert_contains "shell/modules/common/widgets/CavaProcess.qml" "String(root.cfgStereo)"

assert_contains "shell/modules/settings/AdvancedConfig.qml" "text: Translation.tr(\"Cava\")"
assert_contains "shell/modules/settings/AdvancedConfig.qml" "appearance.wallpaperTheming.enableCava"
assert_contains "shell/modules/settings/AdvancedConfig.qml" "title: Translation.tr(\"Cava options\")"
assert_contains "shell/modules/settings/AdvancedConfig.qml" "appearance.cava.sensitivity"
assert_contains "shell/modules/settings/AdvancedConfig.qml" "appearance.cava.bars"
assert_contains "shell/modules/settings/AdvancedConfig.qml" "appearance.cava.framerate"
assert_contains "shell/modules/settings/AdvancedConfig.qml" "appearance.cava.stereo"
assert_contains "shell/modules/settings/AdvancedConfig.qml" "appearance.cava.waveOpacity"
assert_contains "shell/modules/settings/AdvancedConfig.qml" "Config.setNestedValue(\"appearance.cava.waveOpacity\", 30)"

assert_contains "shell/modules/settings/DesktopWidgetsConfig.qml" "background.widgets.mediaControls.visualizerType"
assert_contains "shell/modules/settings/DesktopWidgetsConfig.qml" "background.widgets.mediaControls.visualizerPosition"
assert_contains "shell/modules/settings/DesktopWidgetsConfig.qml" "{ displayName: Translation.tr(\"Bars\"), icon: \"equalizer\", value: \"bars\" }"
assert_contains "shell/modules/settings/DesktopWidgetsConfig.qml" "{ displayName: Translation.tr(\"Off\"), icon: \"visibility_off\", value: \"none\" }"
assert_contains "shell/modules/settings/BackgroundConfig.qml" "background.widgets.mediaControls.visualizerType"
assert_contains "shell/modules/settings/BackgroundConfig.qml" "background.widgets.mediaControls.visualizerPosition"
assert_contains "shell/modules/settings/BackgroundConfig.qml" "{"
assert_contains "shell/modules/settings/BackgroundConfig.qml" "displayName: Translation.tr(\"Bars\")"
assert_contains "shell/modules/settings/BackgroundConfig.qml" "displayName: Translation.tr(\"Off\")"
assert_contains "shell/modules/waffle/settings/pages/WThemesPage.qml" "id: waffleCavaSwitch"
assert_contains "shell/modules/waffle/settings/pages/WThemesPage.qml" "appearance.wallpaperTheming.enableCava"
assert_contains "shell/modules/waffle/settings/pages/WThemesPage.qml" "title: Translation.tr(\"Cava Options\")"
assert_contains "shell/modules/waffle/settings/pages/WThemesPage.qml" "appearance.cava.sensitivity"
assert_contains "shell/modules/waffle/settings/pages/WThemesPage.qml" "appearance.cava.bars"
assert_contains "shell/modules/waffle/settings/pages/WThemesPage.qml" "appearance.cava.framerate"
assert_contains "shell/modules/waffle/settings/pages/WThemesPage.qml" "appearance.cava.waveOpacity"
assert_contains "shell/modules/waffle/settings/pages/WThemesPage.qml" "appearance.cava.stereo"
assert_contains "shell/modules/waffle/settings/pages/WThemesPage.qml" "Config.setNestedValue(\"appearance.cava.waveOpacity\", 30)"

assert_contains "shell/modules/common/widgets/ConfigSelectionArray.qml" "var prev = root.children[index - 1]"
assert_contains "shell/modules/common/widgets/ConfigSelectionArray.qml" "var thisIsOnNewLine = !!prev && prev.y !== paletteButton.y"
assert_contains "shell/modules/settings/ToolsConfig.qml" "property bool fieldEnabled: true"
assert_contains "shell/modules/settings/ToolsConfig.qml" "enabled: field.fieldEnabled"

assert_contains "shell/scripts/cava/generate_config.sh" "#!/bin/bash"
assert_contains "shell/scripts/cava/generate_config.sh" "Usage: generate_config.sh <output_file> [framerate] [sensitivity] [bars] [stereo]"
assert_contains "shell/scripts/cava/generate_config.sh" "FRAMERATE="
assert_contains "shell/scripts/cava/generate_config.sh" "SENSITIVITY="
assert_contains "shell/scripts/cava/generate_config.sh" "BARS="
assert_contains "shell/scripts/cava/generate_config.sh" "STEREO="
assert_contains "shell/scripts/cava/generate_config.sh" "channels = \${CHANNELS}"

mkdir -p "$tmp_dir/bin"
cat > "$tmp_dir/bin/pactl" <<'STUB'
#!/bin/bash
if [[ $1 == "info" ]]; then
  echo "Server Name: PulseAudio (on PipeWire 1.0.0)"
elif [[ $1 == "get-default-sink" ]]; then
  echo "alsa_output.test"
else
  exit 1
fi
STUB
chmod +x "$tmp_dir/bin/pactl"

generated_config="$tmp_dir/cava_config.txt"
PATH="$tmp_dir/bin:$PATH" "$ROOT_DIR/shell/scripts/cava/generate_config.sh" "$generated_config" 75 125 64 true >/dev/null

assert_generated_contains "$generated_config" "framerate = 75"
assert_generated_contains "$generated_config" "sensitivity = 125"
assert_generated_contains "$generated_config" "bars = 64"
assert_generated_contains "$generated_config" "method = pipewire"
assert_generated_contains "$generated_config" "source = alsa_output.test.monitor"
assert_generated_contains "$generated_config" "channels = stereo"

assert_contains "shell/scripts/colors/targets/cava.json" "\"configKey\": \"appearance.wallpaperTheming.enableCava\""
assert_contains "shell/scripts/colors/modules/90-cava.sh" "COLOR_MODULE_ID=\"cava\""
assert_contains "shell/scripts/colors/modules/90-cava.sh" "MARKER_BEGIN=\"# BEGIN ryoku-generated-colors\""
assert_contains "shell/scripts/colors/modules/90-cava.sh" "MARKER_END=\"# END ryoku-generated-colors\""
assert_contains "shell/scripts/colors/modules/90-cava.sh" "CAVA_COLOR_BACKUP="
assert_contains "shell/scripts/colors/modules/90-cava.sh" "print \$0 > backup"
assert_contains "shell/scripts/colors/modules/90-cava.sh" "Restored original cava color section"
assert_contains "shell/scripts/colors/modules/90-cava.sh" "LEGACY_MARKER_BEGIN=\"# BEGIN i\"\"nir-generated-colors\""
assert_contains "shell/scripts/colors/modules/90-cava.sh" "replace_marked_block \"\$color_block\" \"\$LEGACY_MARKER_BEGIN\" \"\$LEGACY_MARKER_END\""
assert_contains "shell/scripts/colors/modules/90-cava.sh" "strip_marked_block \"\$LEGACY_MARKER_BEGIN\" \"\$LEGACY_MARKER_END\""
assert_contains "shell/scripts/colors/modules/90-cava.sh" "config_bool '.appearance.wallpaperTheming.enableCava' false"
assert_contains "shell/scripts/colors/modules/90-cava.sh" "Applied theme colors to cava config"

test_home="$tmp_dir/home"
mkdir -p "$test_home/.config/ryoku-shell" "$tmp_dir/state/quickshell/user/generated" "$tmp_dir/fake-bin"
cat > "$test_home/.config/ryoku-shell/config.json" <<'JSON'
{
  "appearance": {
    "wallpaperTheming": {
      "enableCava": true
    }
  }
}
JSON
cat > "$tmp_dir/state/quickshell/user/generated/palette.json" <<'JSON'
{
  "background": "#101010",
  "primary_container": "#112233",
  "secondary_container": "#223344",
  "primary": "#334455",
  "tertiary": "#445566"
}
JSON
cat > "$tmp_dir/fake-bin/cava" <<'STUB'
#!/bin/bash
exit 0
STUB
chmod +x "$tmp_dir/fake-bin/cava"

HOME="$test_home" \
XDG_CONFIG_HOME="$test_home/.config" \
XDG_STATE_HOME="$tmp_dir/state" \
PATH="$tmp_dir/fake-bin:$PATH" \
  bash "$ROOT_DIR/shell/scripts/colors/modules/90-cava.sh"

cava_config="$test_home/.config/cava/config"
assert_generated_contains "$cava_config" "# BEGIN ryoku-generated-colors"
assert_generated_contains "$cava_config" "[color]"
assert_generated_contains "$cava_config" "background = '#101010'"
assert_generated_contains "$cava_config" "gradient_color_1 = '#112233'"
assert_generated_contains "$cava_config" "# END ryoku-generated-colors"

cat > "$cava_config" <<'EOF'
[general]
framerate = 60
[color]
foreground = '#abcdef'
gradient = 0
[smoothing]
noise_reduction = 10
EOF

HOME="$test_home" \
XDG_CONFIG_HOME="$test_home/.config" \
XDG_STATE_HOME="$tmp_dir/state" \
PATH="$tmp_dir/fake-bin:$PATH" \
  bash "$ROOT_DIR/shell/scripts/colors/modules/90-cava.sh"

assert_generated_contains "$cava_config" "# BEGIN ryoku-generated-colors"
assert_generated_contains "$cava_config" "gradient_color_1 = '#112233'"
assert_generated_not_contains "$cava_config" "foreground = '#abcdef'"

cat > "$test_home/.config/ryoku-shell/config.json" <<'JSON'
{
  "appearance": {
    "wallpaperTheming": {
      "enableCava": false
    }
  }
}
JSON

HOME="$test_home" \
XDG_CONFIG_HOME="$test_home/.config" \
XDG_STATE_HOME="$tmp_dir/state" \
PATH="$tmp_dir/fake-bin:$PATH" \
  bash "$ROOT_DIR/shell/scripts/colors/modules/90-cava.sh"

assert_generated_not_contains "$cava_config" "# BEGIN ryoku-generated-colors"
assert_generated_contains "$cava_config" "foreground = '#abcdef'"
assert_generated_contains "$cava_config" "gradient = 0"
assert_generated_contains "$cava_config" "[smoothing]"

cat > "$test_home/.config/ryoku-shell/config.json" <<'JSON'
{
  "appearance": {
    "wallpaperTheming": {
      "enableCava": true
    }
  }
}
JSON

legacy_begin="# BEGIN ${old_prefix}-generated-colors"
legacy_end="# END ${old_prefix}-generated-colors"
cat > "$cava_config" <<EOF
[general]
bars = 20
$legacy_begin
[color]
gradient = 1
gradient_color_1 = '#000000'
$legacy_end
[smoothing]
noise_reduction = 10
EOF

HOME="$test_home" \
XDG_CONFIG_HOME="$test_home/.config" \
XDG_STATE_HOME="$tmp_dir/state" \
PATH="$tmp_dir/fake-bin:$PATH" \
  bash "$ROOT_DIR/shell/scripts/colors/modules/90-cava.sh"

assert_generated_not_contains "$cava_config" "$legacy_begin"
assert_generated_not_contains "$cava_config" "$legacy_end"
assert_generated_contains "$cava_config" "# BEGIN ryoku-generated-colors"
assert_generated_contains "$cava_config" "gradient_color_1 = '#112233'"
assert_generated_contains "$cava_config" "[smoothing]"

cat > "$test_home/.config/ryoku-shell/config.json" <<'JSON'
{
  "appearance": {
    "wallpaperTheming": {
      "enableCava": false
    }
  }
}
JSON

HOME="$test_home" \
XDG_CONFIG_HOME="$test_home/.config" \
XDG_STATE_HOME="$tmp_dir/state" \
PATH="$tmp_dir/fake-bin:$PATH" \
  bash "$ROOT_DIR/shell/scripts/colors/modules/90-cava.sh"

! grep -qF "# BEGIN ryoku-generated-colors" "$cava_config" || fail "disabled Cava theming should strip managed colors"
! grep -qF "$legacy_begin" "$cava_config" || fail "disabled Cava theming should strip legacy managed colors"

for path in "${write_scope[@]}"; do
  assert_not_contains "$path" "$old_brand"
  assert_not_contains "$path" "In""ir"
  assert_not_contains "$path" "Appearance.$old_prefix"
  assert_not_contains "$path" "scripts/$old_prefix"
  assert_not_contains "$path" "$old_owner"
  assert_not_contains "$path" "/tmp/ryoku-""upstream-shell"
done

echo "PASS: Cava config system is wired for Ryoku"
