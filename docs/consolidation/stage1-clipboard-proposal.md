# Stage 1a proposal: migrate `clipboard` (`Settings.data` → typed `GlobalConfig`)

> **PROPOSAL ONLY, not applied.** This is the exact, ready-to-approve first cut of the
> consolidation (`docs/ryoku-consolidation-plan.md` Stage 1). It is the smallest, most
> reversible domain: **4 keys, 3 write sites in one file, exactly one live reader outside
> settingsgui, zero `GlobalConfig` overlap** (`docs/consolidation/config-map.md:64,134-146`).
> Approve and I apply it in one pass, then stop for sign-off before the next domain.

## Current state (evidence)
- Store: `Settings.data.clipboard` (settings-gui `JsonAdapter`, `settings-gui/settings.json`):
  `enabled` (bool), `maxEntries` (int), `autoCleanup` (string `off|daily|weekly`).
- Writer/UI: `shell/settingsgui/Modules/Panels/Settings/Tabs/Launcher/ClipboardSubTab.qml`
 , reads `:30,36,42,51,68`, writes `:31,45,69`.
- **Live reader outside settingsgui** (the only cross-surface coupling):
  `shell/modules/ClipboardMaintenance.qml:17` `readonly property var cfg: Settings.data.clipboard`,
  consumed `:29,35,48,54` (`cfg.enabled`, `cfg.maxEntries`, `cfg.autoCleanup`).

## The change (file-by-file)

**1. New `shell/plugin/src/Ryoku/Config/clipboardconfig.hpp`** (header-only, like
`AppearanceTransparency`):
```cpp
#pragma once
#include "configobject.hpp"
#include <qstring.h>
namespace ryoku::config {
class ClipboardConfig : public ConfigObject {
    Q_OBJECT
    QML_ANONYMOUS
    CONFIG_PROPERTY(bool, enabled, true)
    CONFIG_PROPERTY(int, maxEntries, 100)
    CONFIG_PROPERTY(QString, autoCleanup, QStringLiteral("off"))
public:
    explicit ClipboardConfig(QObject* parent = nullptr) : ConfigObject(parent) {}
};
} // namespace ryoku::config
```
(Defaults will be set to the exact values in `settingsgui/Assets/settings-default.json` at
apply, so fresh-install behavior is unchanged.)

**2. `shell/plugin/src/Ryoku/Config/config.hpp`**, register the section (mirrors the other
~19 sections): add `class ClipboardConfig;` forward-decl, `Q_MOC_INCLUDE("clipboardconfig.hpp")`,
and `CONFIG_SUBOBJECT(ClipboardConfig, clipboard)`.

**3. `GlobalConfig` constructor (config.cpp)**, add `m_clipboard(new ClipboardConfig(this))`
to the init list (verified against the actual ctor at apply). **CMakeLists**: add the header
to the `ryoku-config` target if headers are listed explicitly (else the glob picks it up).

**4. `shell/modules/ClipboardMaintenance.qml`**, repoint the one binding:
`import Ryoku.Config` and `readonly property var cfg: GlobalConfig.clipboard` (drop the
`Settings`-only import if now unused). The `cfg.enabled/maxEntries/autoCleanup` uses are
unchanged (same shape).

**5. `ClipboardSubTab.qml`**, `import Ryoku.Config`; repoint the 3 reads + 3 writes to
`GlobalConfig.clipboard.*` and call `GlobalConfig.save()` in each handler (matching the
`AppearanceSubTab` pattern). `ClipboardService.clear()` / the "Clear now" button are
unrelated and untouched.

**6. Migration `migrations/<ts>.sh`** (`[global]`, additive, idempotent):
```bash
echo "Move clipboard history settings into the typed shell config"
src="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/settings-gui/settings.json"
dst="${XDG_CONFIG_HOME:-$HOME/.config}/ryoku/shell.json"
ryoku-cmd-missing jq && { echo "  jq missing; skipping"; exit 0; }
[[ -f $src ]] || exit 0
clip="$(jq -c '.clipboard // empty' "$src")"
[[ -n $clip ]] || exit 0
mkdir -p "$(dirname "$dst")"; [[ -f $dst ]] || printf '{}\n' >"$dst"
tmp="$(mktemp)"
if jq --argjson c "$clip" '.clipboard = ((.clipboard // {}) + $c)' "$dst" >"$tmp"; then
  mv "$tmp" "$dst"; else rm -f "$tmp"; fi
ryoku-cmd-present systemctl && systemctl --user restart ryoku-shell.service >/dev/null 2>&1 || true
```
(Copies the user's existing values; does **not** touch the old store, that key is only
dropped at the Stage 1g retirement, gated separately.)

## Verification (I run all before reporting back)
- `cmake --build shell/build --target ryoku-config` → compiles + links the new section.
- `qmllint` clean on `ClipboardMaintenance.qml` + `ClipboardSubTab.qml`.
- Migration: `bash -n` + a jq dry-run on a sample `settings.json` confirming `.clipboard`
  lands in `shell.json` with user values preserved.
- Behavior: toggle "Manage clipboard history" in Settings → confirm
  `ClipboardMaintenance.qml`'s trim/age `Timer.running` bindings flip (the maintenance
  reacts live through `GlobalConfig` NOTIFY), the non-settings-surface check.

## Risk / rollback
- **Risk: low.** 4 keys, one reader, no schema-merge (no existing `GlobalConfig.clipboard`).
- **Reversible:** additive (old store untouched); revert the commit to undo. The migration
  only ever runs once per install.

## Net effect
"Manage clipboard history" + limit + auto-cleanup become typed, live `GlobalConfig.clipboard`
settings (same live-apply model as the transparency controls), and one of the three config
stores loses its first domain, proving the Stage 1 pattern on the safest possible slice.
