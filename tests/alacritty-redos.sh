#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

python3 - "$ROOT_DIR" <<'PY'
import importlib.util
import signal
import sys
import tempfile
from pathlib import Path

root = Path(sys.argv[1])
module_path = root / "shell/scripts/colors/generate_terminal_configs.py"

spec = importlib.util.spec_from_file_location("generate_terminal_configs", module_path)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class Timeout(Exception):
  pass


def timeout_handler(_signum, _frame):
  raise Timeout


signal.signal(signal.SIGALRM, timeout_handler)

content = (
  "[general]\n"
  + ("\n" * 28)
  + "[colors]\n"
  + 'working_directory = "/tmp"\n'
  + "[colors.primary]\n"
  + 'foreground = "#ffffff"\n'
)

with tempfile.TemporaryDirectory() as tmpdir:
  config_path = Path(tmpdir) / "alacritty.toml"
  config_path.write_text(content)

  signal.setitimer(signal.ITIMER_REAL, 0.5)
  try:
    modified, message = module.fix_alacritty_import_order(str(config_path))
  except Timeout:
    raise SystemExit(
      "fix_alacritty_import_order timed out on newline-heavy [general] section"
    )
  finally:
    signal.setitimer(signal.ITIMER_REAL, 0)

  result = config_path.read_text()

  if not modified:
    raise SystemExit(f"expected config to be modified, got: {message}")

  general_sections = sum(
    1 for line in result.splitlines() if line.strip() == "[general]"
  )
  if general_sections != 1:
    raise SystemExit("expected exactly one [general] section")

  if 'import = ["~/.config/alacritty/colors.toml"]' not in result:
    raise SystemExit("expected generated import line")

  if 'working_directory = "/tmp"' not in result:
    raise SystemExit("expected misplaced general option to be preserved")

print("PASS: alacritty ReDoS regression")
PY
