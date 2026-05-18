#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_UPSTREAM_DIR="$(cd "$ROOT_DIR/../i""nir-upstream" 2>/dev/null && pwd || true)"
UPSTREAM_DIR="${UPSTREAM_DIR:-$DEFAULT_UPSTREAM_DIR}"
UPSTREAM_REF="${UPSTREAM_REF:-7826b97e}"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"

  grep -qF -- "$needle" "$ROOT_DIR/$path" || fail "$path should contain: $needle"
}

assert_not_contains() {
  local path="$1"
  local needle="$2"

  ! grep -qF -- "$needle" "$ROOT_DIR/$path" || fail "$path should not contain: $needle"
}

upstream_available=0
if [[ -n $UPSTREAM_DIR && -d $UPSTREAM_DIR/.git ]]; then
  upstream_available=1
fi

python3 - "$ROOT_DIR" <<'PY'
import importlib.util
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
manager_path = root / "shell/translations/tools/translation-manager.py"
spec = importlib.util.spec_from_file_location("translation_manager", manager_path)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
manager = mod.TranslationManager(str(root / "shell/translations"), str(root / "shell"), yes_mode=True)
source_keys = manager.extract_translatable_texts()

for path in sorted((root / "shell/translations").glob("*.json")):
  data = json.loads(path.read_text(encoding="utf-8"))
  keep_keys = {
    key for key, value in data.items()
    if isinstance(value, str) and value.strip().endswith("/*keep*/")
  }
  expected = source_keys | keep_keys
  missing = sorted(expected - set(data))
  extra = sorted(set(data) - expected)
  if missing or extra:
    print(f"{path.name}: missing={len(missing)} extra={len(extra)}", file=sys.stderr)
    if missing:
      print(f"missing example: {missing[0]}", file=sys.stderr)
    if extra:
      print(f"extra example: {extra[0]}", file=sys.stderr)
    sys.exit(1)
PY

node - "$ROOT_DIR" "$UPSTREAM_DIR" "$UPSTREAM_REF" "$upstream_available" <<'NODE'
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const root = process.argv[2];
const upstream = process.argv[3];
const upstreamRef = process.argv[4];
const upstreamAvailable = process.argv[5] === '1';
const localDir = path.join(root, 'shell/translations');
const oldBrand = 'i' + 'NiR';
const oldTitle = 'I' + 'nir';
const oldLower = 'i' + 'nir';
const oldUpper = 'I' + 'NIR';
const oldOwner = 'snow' + 'arch';

function normalizeString(value) {
  return value
    .replaceAll(oldBrand, 'Ryoku')
    .replaceAll(oldTitle, 'Ryoku')
    .replaceAll(oldUpper, 'RYOKU')
    .replaceAll(oldLower, 'ryoku')
    .replaceAll(oldOwner, 'neur0map')
    .replaceAll('Snow' + 'arch', 'Neur0map');
}

const upstreamFeatureKeys = [
  'AI Providers',
  'AI Settings',
  'Calendar Sources',
  'Desktop Widgets',
  'Audio visualizer',
  'Game Mode Overrides',
  'Auto-hide OSD during fullscreen',
  'Suppress notifications',
  'Disable Niri animations',
  'Booru download paths',
  '10 MB fits Discord Free'
];

const enUS = JSON.parse(fs.readFileSync(path.join(localDir, 'en_US.json'), 'utf8'));
for (const key of upstreamFeatureKeys) {
  if (!(key in enUS)) {
    console.error(`Missing expected upstream/current feature translation key: ${key}`);
    process.exit(1);
  }
}

if (upstreamAvailable) {
  for (const file of fs.readdirSync(localDir).filter(f => f.endsWith('.json')).sort()) {
    const local = JSON.parse(fs.readFileSync(path.join(localDir, file), 'utf8'));
    const upstreamRaw = JSON.parse(execFileSync('git', ['-C', upstream, 'show', `${upstreamRef}:translations/${file}`], { encoding: 'utf8' }));
    const upstreamNormalized = {};

    for (const [key, value] of Object.entries(upstreamRaw)) {
      upstreamNormalized[normalizeString(key)] = typeof value === 'string' ? normalizeString(value) : value;
    }

    const shared = Object.keys(upstreamNormalized).filter(key => key in local);
    if (shared.length < 3600) {
      console.error(`${file}: expected broad upstream v2.25 overlap, got ${shared.length}`);
      process.exit(1);
    }
  }
} else {
  console.log('WARN: upstream checkout unavailable; skipped optional upstream overlap check.');
}
NODE

auto_tool="shell/translations/tools/auto-translate.js"
gemini_tool="shell/scripts/ai/gemini-translate.sh"
old_config_dir="i""nir_config_dir"
old_config_file="i""nir_config_file"

assert_contains "$auto_tool" "function sanitizeTranslation"
assert_contains "$auto_tool" "function writeAtomic"
assert_contains "$auto_tool" "replace(/[\\uFFFD\\uD800-\\uDFFF]/g, '')"
assert_contains "$auto_tool" "JSON.parse(json)"
assert_contains "$auto_tool" "fs.renameSync(tmp, filePath)"

assert_contains "$gemini_tool" "#!/bin/bash"
assert_contains "$gemini_tool" "TARGET_FILE="
assert_contains "$gemini_tool" "notify_error()"
assert_contains "$gemini_tool" ".apiKeys.gemini // empty"
assert_contains "$gemini_tool" "--rawfile content"
assert_contains "$gemini_tool" "--max-time 300 --fail-with-body --silent --show-error"
assert_contains "$gemini_tool" 'curl_status=$?'
assert_contains "$gemini_tool" ".candidates[0].content.parts[0].text // empty"
assert_contains "$gemini_tool" 'tmp_file="${TARGET_FILE}.tmp.$$"'
assert_contains "$gemini_tool" 'mv "$tmp_file" "$TARGET_FILE"'
assert_contains "$gemini_tool" "ryoku_shell_config_dir"
assert_contains "$gemini_tool" "ryoku_shell_config_file"
assert_not_contains "$gemini_tool" "$old_config_dir"
assert_not_contains "$gemini_tool" "$old_config_file"

echo "PASS: translations upstream sync"
