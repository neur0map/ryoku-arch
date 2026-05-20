#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

launcher="shell/scripts/ryoku-shell"
settings_qml="shell/ryokuSettings.qml"
shell_entry="shell/shell.qml"
config_schema="shell/modules/common/Config.qml"
extras_config="shell/modules/settings/ExtrasConfig.qml"
window_rules="config/niri/config.d/30-window-rules.kdl"
default_window_rules="shell/defaults/niri/config.d/30-window-rules.kdl"

legacy_settings="shell/settings.qml"
legacy_niri="shell/modules/settings/NiriConfig.qml"

[[ -f "$settings_qml" ]] || fail "official Ryoku settings entrypoint should exist"
[[ -f "$legacy_settings" ]] || fail "legacy settings.qml must stay in the repo for reference"
[[ -f "$legacy_niri" ]] || fail "legacy Niri settings must stay in the repo for reference"

grep -q 'ryoku-settings-window' "$launcher" \
  || fail "ryoku-shell should expose ryoku-settings-window"

grep -q 'legacy-settings-window' "$launcher" \
  || fail "ryoku-shell should keep a legacy settings entrypoint for reference"

grep -q 'open_detached_qml_window "$config_dir" "ryokuSettings.qml"' "$launcher" \
  || fail "ryoku-settings-window should launch ryokuSettings.qml"

grep -q 'open_detached_qml_window "$config_dir" "settings.qml"' "$launcher" \
  || fail "legacy-settings-window should launch the old settings.qml reference"

awk '/settings\|open\)/,/settings-window\|ryoku-settings-window\)/ { if ($0 ~ /open_settings_surface/) found=1 } END { exit found ? 0 : 1 }' "$launcher" \
  || fail "primary ryoku-shell settings command should launch official settings for Mod+Comma"

grep -q '"settings"' "$shell_entry" \
  || fail "the live settings IPC path should open through the primary settings command"

grep -q 'RYOKU_SETTINGS_MODE' "$launcher" \
  || fail "ryoku-settings-window should support centered/window launch modes"

grep -q -- '--window' "$launcher" \
  || fail "ryoku-settings-window should expose a normal window mode"

grep -q -- '--centered' "$launcher" \
  || fail "ryoku-settings-window should expose an explicit centered mode"

grep -q 'Ryoku Settings' "$settings_qml" \
  || fail "official settings should identify itself as Ryoku Settings"

grep -q 'RYOKU_SETTINGS_PAGE' "$settings_qml" \
  || fail "official settings should support direct page routing"

grep -q 'RYOKU_SETTINGS_SUBTAB' "$settings_qml" \
  || fail "official settings should support direct subtab routing"

forbidden_re='noc''talia|pro''totype|temporary sett''ings|temp sett''ings|Settings La''b|settings la''b|RYOKU_SETTINGS_LA''B|noc''taliaSettings'
for active_file in "$settings_qml" "$launcher" "$shell_entry" "$window_rules" "$default_window_rules"; do
  if grep -Eiq "$forbidden_re" "$active_file"; then
    fail "$active_file should not contain old external or experimental naming"
  fi
done

grep -q 'readonly property bool centeredMode' "$settings_qml" \
  || fail "settings_qml should default to centered window placement"

grep -q 'function centerWindow' "$settings_qml" \
  || fail "settings_qml should center itself when launched in centered mode"

grep -q 'readonly property var tabsModel' "$settings_qml" \
  || fail "settings_qml should use a Ryoku tab model"

grep -q '{ key: "services"' "$settings_qml" \
  || fail "Services should be a first-class official settings tab"

if grep -q 'miscellaneous_services' "$settings_qml"; then
  fail "Services should not use unsupported miscellaneous_services icon ligature because it renders as overlapping text"
fi

if awk '
  /id: servicesPage/ { services=1 }
  /id: toolsPage/ { services=0 }
  services && /ServicesConfig.qml/ { found=1 }
  END { exit found ? 0 : 1 }
' "$settings_qml"; then
  fail "Services should be native official UI, not an embedded legacy ServicesConfig page"
fi

grep -q 'AI providers' "$settings_qml" \
  || fail "native Services should expose AI provider settings"

grep -q 'Idle and sleep' "$settings_qml" \
  || fail "native Services should expose idle and sleep controls"

grep -q 'Music recognition' "$settings_qml" \
  || fail "native Services should expose music recognition controls"

grep -q 'Weather service' "$settings_qml" \
  || fail "native Services should expose weather service controls"

grep -q 'readonly property int sidebarWidth' "$settings_qml" \
  || fail "settings_qml should define stable frame/sidebar dimensions"

grep -q 'readonly property int scrollGutterWidth' "$settings_qml" \
  || fail "settings_qml should reserve a scroll gutter so controls do not overlap scrollbars"

grep -q 'component SettingsPanelBox' "$settings_qml" \
  || fail "settings_qml should copy the Ryoku two-pane panel frame shape"

grep -q 'GlassBackground' "$settings_qml" \
  || fail "Aurora style should use Ryoku's glass background component instead of opaque rectangles"

grep -q 'auroraTransparency' "$settings_qml" \
  || fail "settings glass surfaces should use Aurora transparency tokens"

grep -q 'wallpaperOpacity' "$settings_qml" \
  || fail "settings glass surfaces should lower wallpaper opacity so the transparent window reads as glass"

grep -q 'anchors.margins: 0' "$settings_qml" \
  || fail "settings frame should fill the window; transparent outer gutters show compositor focus colors"

if grep -q 'anchors.margins: 8' "$settings_qml"; then
  fail "settings frame must not leave a blue compositor-colored moat around the panel"
fi

grep -q 'component SettingsNavItem' "$settings_qml" \
  || fail "settings_qml should render Ryoku sidebar rows"

grep -q 'component SettingsSubTabs' "$settings_qml" \
  || fail "settings_qml should split dense pages into Ryoku subtabs"

grep -q 'component SettingsSubTabs: Flow' "$settings_qml" \
  || fail "settings subtabs should wrap instead of clipping or scrolling labels"

grep -q 'Layout.preferredHeight: childrenRect.height' "$settings_qml" \
  || fail "settings subtabs should grow vertically when options wrap"

if grep -q 'implicitHeight: childrenRect.height' "$settings_qml"; then
  fail "SettingsSubTabs should not assign Flow.implicitHeight because it is read-only"
fi

if grep -q 'contentWidth: tabsRow.implicitWidth' "$settings_qml"; then
  fail "settings subtabs should not rely on a clipped horizontal scroller"
fi

grep -q 'component SettingsSettingCard' "$settings_qml" \
  || fail "settings_qml should use curated setting cards instead of dumping switch lists"

grep -q 'component SettingsModeSegment' "$settings_qml" \
  || fail "settings_qml should use segmented mode controls for mutually exclusive settings"

grep -q 'component SettingsSwitch' "$settings_qml" \
  || fail "settings_qml should use native row controls instead of old accordion pages"

grep -q 'component SettingsCombo' "$settings_qml" \
  || fail "settings_qml should include Ryoku combo rows"

grep -q 'id: comboWheelGuard' "$settings_qml" \
  || fail "settings combo dropdowns should guard wheel events from leaking into page scroll"

grep -q 'wheel.accepted = true' "$settings_qml" \
  || fail "settings combo dropdown wheel events should be consumed at dropdown bounds"

grep -q 'component SettingsSpinBox' "$settings_qml" \
  || fail "settings_qml should include Ryoku numeric rows"

grep -q 'component SettingsConfigBrowser' "$settings_qml" \
  || fail "settings_qml should include a native exhaustive config browser for legacy settings not curated into the main pages"

grep -q 'import Quickshell.Io' "$settings_qml" \
  || fail "settings_qml should import Quickshell.Io for live display helper processes"

grep -q 'id: advancedInspector' "$settings_qml" \
  || fail "raw config coverage should be presented as an Advanced Inspector"

grep -q 'function flattenConfigRows' "$settings_qml" \
  || fail "settings_qml should build config-browser rows from the live Config tree"

grep -q 'Config.getNestedValue(rowData.path' "$settings_qml" \
  || fail "generic config rows should read values from Config by path"

grep -q 'Config.setNestedValue(rowData.path' "$settings_qml" \
  || fail "generic config rows should write values through Config by path"

grep -q 'Color Scheme' "$settings_qml" \
  || fail "settings_qml should provide a native Color Scheme page"

grep -q 'Light | Dark | Auto | Schedule' "$settings_qml" \
  || fail "theme mode should be a user-friendly segmented control, not a single dark-mode switch"

grep -q 'Quick Rice' "$settings_qml" \
  || fail "General should expose a Quick Rice section for common appearance tuning"

grep -q 'background.widgets.notes.enable' "$settings_qml" \
  || fail "official desktop widget gallery should expose Notes"

grep -q 'background.widgets.calendarUpcoming.enable' "$settings_qml" \
  || fail "official desktop widget gallery should expose Upcoming Events"

grep -q 'Use wallpaper colors' "$settings_qml" \
  || fail "Quick Rice should expose a user-friendly wallpaper color toggle"

grep -q 'Favorite theme' "$settings_qml" \
  || fail "Quick Rice should expose favorite theme selection"

# The Shell style combo moved out of the content-pane header and into
# Appearance > Style sub-tab during sub-spec #02b verification. The combo
# is now the canonical single entry point and lives inside the page, not
# in the chrome.

grep -q 'function favoriteThemePresets' "$settings_qml" \
  || fail "Quick Rice favorite themes should load the favorite preset objects, not text-only combo options"

grep -q 'component SettingsFavoriteThemeCard' "$settings_qml" \
  || fail "Quick Rice favorite themes should use visual swatch cards"

grep -q 'Automatic transparency' "$settings_qml" \
  || fail "Quick Rice should explain and expose automatic transparency before manual sliders"

grep -q '"appearance.transparency.automatic": false' "$settings_qml" \
  || fail "manual transparency sliders should disable automatic transparency so movement has visible effect"

grep -q 'Shell surface transparency' "$settings_qml" \
  || fail "Quick Rice should expose background transparency"

grep -q 'Active window opacity' "$settings_qml" \
  || fail "Quick Rice should explain that Niri only exposes inactive window opacity globally"

grep -q 'appearance.transparency.contentTransparency' "$settings_qml" \
  || fail "Quick Rice should expose content transparency"

grep -q 'Inactive window opacity' "$settings_qml" \
  || fail "Quick Rice should expose inactive window opacity"

grep -q 'window-rules", "inactive-opacity' "$settings_qml" \
  || fail "inactive window opacity should write through the existing Niri window-rules helper"

grep -q 'function setThemeMode' "$settings_qml" \
  || fail "settings_qml should persist theme mode user intent"

grep -q 'ThemeService.applyCurrentTheme' "$settings_qml" \
  || fail "standalone settings should apply the active Ryoku theme when Config becomes ready"

grep -q 'function readableOn' "$settings_qml" \
  || fail "selected controls should calculate readable text against accent colors"

grep -q 'appearance.themeMode' "$settings_qml" \
  || fail "theme mode should use a dedicated persisted setting instead of derived Appearance state"

grep -q 'component SettingsThemePresetCard' "$settings_qml" \
  || fail "appearance should expose real theme preset swatches instead of text-only placeholders"

grep -q 'ThemePresets.presets' "$settings_qml" \
  || fail "appearance should use the existing Ryoku theme preset registry"

grep -q 'ThemeService.setTheme' "$settings_qml" \
  || fail "theme preset cards should apply themes through ThemeService"

grep -q 'appearance.favoriteThemes' "$settings_qml" \
  || fail "theme preset cards should keep favorite theme support"

awk '
  /component SettingsThemePresetCard/ { cardComponent=1 }
  cardComponent && /id: cardMouse/ { cardMouseLine=NR }
  cardComponent && /id: favMouse/ { favMouseLine=NR }
  cardComponent && /^  component / && NR > cardMouseLine && favMouseLine { cardComponent=0 }
  END { exit (cardMouseLine > 0 && favMouseLine > 0 && cardMouseLine < favMouseLine) ? 0 : 1 }
' "$settings_qml" \
  || fail "theme favorite star should sit above the card click target instead of being swallowed by it"

grep -q 'Templates' "$settings_qml" \
  || fail "settings_qml should expose the Ryoku template section"

grep -q 'terminalColorAdjustments.saturation' "$settings_qml" \
  || fail "templates should expose terminal color adjustment controls from legacy themes"

grep -q 'Audio' "$settings_qml" \
  || fail "settings_qml should provide a native Audio page"

grep -q 'scriptPath.*Quickshell.shellPath("scripts/niri-config.py")' "$settings_qml" \
  || fail "display settings should use the existing Niri config helper"

grep -q 'function loadOutputs' "$settings_qml" \
  || fail "display settings should query connected outputs"

grep -q 'apply-output' "$settings_qml" \
  || fail "display settings should apply output changes through the Niri helper"

grep -q 'persist-output' "$settings_qml" \
  || fail "display settings should persist output changes through the Niri helper"

grep -q 'Refresh rate' "$settings_qml" \
  || fail "display settings should expose refresh-rate selection"

grep -q 'ShellUpdates.localVersion' "$settings_qml" \
  || fail "about page should show the real Ryoku shell version"

grep -q 'Check updates' "$settings_qml" \
  || fail "about page should keep the old update check action"

grep -q 'shellUpdates.channel' "$settings_qml" \
  || fail "about page should expose the update channel selector"

grep -q 'unstable-dev' "$settings_qml" \
  || fail "about page should let users select the unstable-dev update channel"

grep -q 'iNiR' "$settings_qml" \
  || fail "about page should keep the old integration credits"

grep -q 'github.com/snowarch/inir' "$settings_qml" \
  || fail "about page should keep upstream credit links"

if grep -q 'source: app.pages\\[index\\].component' "$settings_qml"; then
  fail "settings_qml should not embed the old settings page loader"
fi

if grep -q 'modules/settings/GeneralConfig.qml' "$settings_qml"; then
  fail "settings_qml should not wrap the old GeneralConfig accordion page"
fi

if grep -q 'PlaceholderPage' "$settings_qml"; then
  fail "settings_qml should not expose placeholder settings pages"
fi

if grep -q 'Open legacy' "$settings_qml"; then
  fail "settings_qml should not route users back to legacy settings from the new frame"
fi

if awk '
  /id: advancedPage/ { advanced=1 }
  /id: aboutPage/ { advanced=0 }
  /SettingsConfigBrowser[[:space:]]*{/ && !advanced { found=1 }
  END { exit found ? 0 : 1 }
' "$settings_qml"; then
  fail "normal settings pages should not show the exhaustive config browser; keep it in Advanced"
fi

if grep -q 'prefixes: \\[""\\]' "$settings_qml"; then
  fail "Advanced should not eagerly flatten the entire Config tree when the tab opens"
fi

switch_count=$(grep -c 'SettingsSwitch[[:space:]]*{' "$settings_qml" || true)
if (( switch_count > 70 )); then
  fail "settings_qml should not expose a wall of switches ($switch_count found)"
fi

if grep -q 'model: row.options ? row.options.length' "$settings_qml"; then
  fail "SettingsCombo should use the real options model, not an integer count"
fi

if grep -q '^    SpinBox {' "$settings_qml"; then
  fail "SettingsSpinBox should not use Qt's default SpinBox control"
fi

if awk '/component SettingsSwitch/,/^  component / { if ($0 ~ /onToggled:/) found=1 } END { exit found ? 0 : 1 }' "$settings_qml"; then
  fail "SettingsSwitch should write only from user clicks, not programmatic checked changes"
fi

grep -q 'StyledSlider {' "$settings_qml" \
  || fail "SettingsValueSlider should use the themed StyledSlider control"

grep -q 'onClicked: row.toggled(checked)' "$settings_qml" \
  || fail "SettingsSwitch should persist the checked value from the user click path"

grep -q 'clip: false' "$settings_qml" \
  || fail "settings frame should not clip dropdown popups"

grep -q 'Keys.onDownPressed' "$settings_qml" \
  || fail "SettingsCombo should support keyboard navigation"

grep -q 'row.openDropdown()' "$settings_qml" \
  || fail "SettingsCombo should explicitly open its custom dropdown from mouse and keyboard input"

grep -q 'parent: app.contentItem' "$settings_qml" \
  || fail "SettingsCombo dropdown should render on the application content item instead of inside clipped page content"

grep -q 'anchors.rightMargin: app.scrollGutterWidth' "$settings_qml" \
  || fail "page content should reserve right padding for scrollbars and dropdown focus rings"

grep -q 'contentHeight: bodyColumn.implicitHeight' "$settings_qml" \
  || fail "SettingsPageBody should set contentHeight so tall theme/template/about/advanced pages scroll"

grep -q 'component SettingsPageBody' "$settings_qml" \
  || fail "SettingsPage should keep subtabs fixed and scroll only the page body"

grep -q 'component SettingsStackLayout' "$settings_qml" \
  || fail "tabbed settings pages should use a stack that sizes only the active subtab"

grep -q 'activeStackItem' "$settings_qml" \
  || fail "SettingsStackLayout should ignore hidden tab content when calculating scroll height"

grep -q 'Layout.preferredHeight: StackLayout.isCurrentItem ? implicitHeight : 0' "$settings_qml" \
  || fail "inactive subtabs should not keep their old scroll height"

grep -q 'contentItem: Column' "$settings_qml" \
  || fail "setting cards should use a plain Control content column to avoid nested polish loops"

grep -q 'component SettingsColorField' "$settings_qml" \
  || fail "focus-ring colors should expose hex entry, color picker, and swatches"

grep -q 'ColorDialog' "$settings_qml" \
  || fail "color code rows should include a real color picker dialog"

if grep -q 'profile\.avatar\|SettingsAvatarPicker\|avatarImageDialog\|Avatar image' "$settings_qml"; then
  fail "official settings should not expose the dead profile.avatar control"
fi

grep -q 'userAvatarPaths' shell/modules/common/Directories.qml \
  || fail "real shell avatar sources should remain in Directories.qml"

grep -q 'AccountsService/icons' shell/modules/common/Directories.qml \
  || fail "real shell avatar sources should keep AccountsService support"

grep -q '\.face' shell/modules/common/Directories.qml \
  || fail "real shell avatar sources should keep ~/.face support"

grep -q 'settingsUi.focusRing.followTheme' "$settings_qml" \
  || fail "focus ring should be able to follow active Ryoku theme colors"

grep -q 'Follow theme focus ring' "$settings_qml" \
  || fail "Quick Rice should expose focus-ring theme-follow as a common rice control"

grep -q 'function loadInput' "$settings_qml" \
  || fail "official settings should load legacy Niri input settings"

grep -q 'function loadCursorThemes' "$settings_qml" \
  || fail "official settings should enumerate installed cursor themes"

grep -q 'get-input' "$settings_qml" \
  || fail "official settings should read cursor state through the existing Niri helper"

grep -q 'list-cursor-themes' "$settings_qml" \
  || fail "official settings should use the existing cursor theme helper"

grep -q 'Cursor theme' "$settings_qml" \
  || fail "official settings should expose the legacy cursor theme control"

grep -q 'cursor.xcursor-theme' "$settings_qml" \
  || fail "cursor theme should write through the existing Niri cursor key"

grep -q 'Cursor size' "$settings_qml" \
  || fail "official settings should expose the legacy cursor size control"

grep -q 'cursor.xcursor-size' "$settings_qml" \
  || fail "cursor size should write through the existing Niri cursor key"

grep -q 'Hide cursor while typing' "$settings_qml" \
  || fail "official settings should expose the legacy hide-cursor-while-typing toggle"

grep -q 'cursor.hide-when-typing' "$settings_qml" \
  || fail "hide-cursor toggle should write through the existing Niri cursor key"

grep -q 'Cursor theme' "$legacy_niri" \
  || fail "legacy cursor implementation should remain available for reference"

grep -q 'component SettingsCopyPathRow' "$settings_qml" \
  || fail "config and dotfile paths should be selectable and one-click copyable"

grep -q 'Quickshell.clipboardText = row.path' "$settings_qml" \
  || fail "path copy controls should write to the clipboard"

grep -q 'AppLauncher.slotDefinitions' "$settings_qml" \
  || fail "preferred apps should use all AppLauncher slots from the old settings"

grep -q 'wStartMenu' "$settings_qml" \
  || fail "Waffle settings should toggle real Waffle panel ids"

if grep -q 'waffles.launcher.enabled' "$settings_qml"; then
  fail "Waffle page should not use placeholder config keys"
fi

grep -q 'Math.round(Number(CustomWidgets.getConfigValue' shell/modules/settings/DesktopWidgetsConfig.qml \
  || fail "custom widget integer settings should coerce saved values before assigning StyledSpinBox.value"

grep -q 'function searchIndexRows' "$settings_qml" \
  || fail "search should include migrated config rows, not only a small hand-written index"

grep -q 'Focus ring' "$settings_qml" \
  || fail "settings_qml should expose the existing Niri focus ring settings"

grep -q 'focus-ring.enabled' "$settings_qml" \
  || fail "focus ring controls should write through the existing Niri config helper"

if grep -q 'Install qylock' "$settings_qml"; then
  fail "login tab should not offer a qylock re-download/install action"
fi

grep -q 'auroraLightStyle' "$settings_qml" \
  || fail "Aurora light mode should use separate glass and contrast tuning"

if grep -q 'auroraFrameTransparency: auroraLightStyle ? 0\\.0' "$settings_qml"; then
  fail "Aurora light mode transparency must stay glassy, not nearly opaque"
fi

grep -q 'Appearance.m3colors.darkmode = dark' "$settings_qml" \
  || fail "theme mode switches should update the visible settings colors immediately"

grep -q 'Config.setNestedValue' "$settings_qml" \
  || fail "settings_qml should exercise the existing Ryoku config system"

grep -q 'function applyGlobalStyle' "$settings_qml" \
  || fail "settings_qml should wire global style with the existing side effects"

grep -q 'MaterialThemeLoader.applySchemeVariant' "$settings_qml" \
  || fail "settings_qml should apply palette variants through MaterialThemeLoader"

for path in \
  'appearance.typography.titleFont' \
  'appearance.wallpaperTheming.enableAppsAndShell' \
  'appearance.wallpaperTheming.terminals.kitty' \
  'appearance.cava.sensitivity' \
  'appearance.globalStyleCornerStyles.material' \
  'appearance.transparency.backgroundTransparency' \
  'background.backdrop.enable' \
  'background.transition.duration' \
  'background.parallax.enable' \
  'background.enableAnimation' \
  'background.effects.enableBlur' \
  'background.widgets.clock.enable' \
  'bar.modules.sysTray' \
  'bar.modules.rightSidebarButton' \
  'bar.resources.cpuWarningThreshold' \
  'bar.tray.monochromeIcons' \
  'bar.utilButtons.showScreenRecord' \
  'bar.workspaces.alwaysShowNumbers' \
  'dock.enable' \
  'controlPanel.compactMode' \
  'sidebar.leftWidth' \
  'altSwitcher.preset' \
  'notifications.timeoutNormal' \
  'notifications.timeoutCritical' \
  'osd.timeout' \
  'lock.clock.style' \
  'display.primaryMonitor' \
  'screenRecord.qualityPreset' \
  'screenRecord.videoCodec' \
  'screenRecord.discordCompress.targetSizeMb' \
  'regionSelector.screenshotNameFormat' \
  'apps.terminal' \
  'updates.checkInterval' \
  'enabledPanels' \
  'panelFamily' \
  'resources.updateInterval' \
  'gameMode.autoDetect' \
  'gameMode.disableEffects' \
  'waffles.modules.widgets'; do
  grep -q "$path" "$settings_qml" \
    || fail "settings_qml should port existing setting $path"
done

for tab in \
  'Themes' \
  'Panels' \
  'Modules' \
  'Services' \
  'Advanced' \
  'Shortcuts' \
  'Tools' \
  'Waffle Style' \
  'Compositor' \
  'Login screen' \
  'Desktop Widgets' \
  'Extras'; do
  grep -q "$tab" "$settings_qml" \
    || fail "settings_qml should include a migrated $tab tab"
done

grep -q '{ key: "extras"' "$settings_qml" \
  || fail "Extras should be a first-class official settings tab"

grep -q 'Package manager' "$extras_config" \
  || fail "Extras should mark GPK as the package manager"

grep -q 'gpk' "$extras_config" \
  || fail "Extras should launch gpk-bin package-manager commands"

grep -q 'launchGpkPrompt("install")' "$extras_config" \
  || fail "Extras should expose GPK package install"

grep -q 'launchGpkPrompt("remove")' "$extras_config" \
  || fail "Extras should expose GPK package uninstall"

grep -q 'launchGpkPrompt("upgrade")' "$extras_config" \
  || fail "Extras should expose GPK package update"

grep -q 'gpk-bin' install/ryoku-aur.packages \
  || fail "Ryoku default AUR packages should ship gpk-bin"

grep -q 'component SettingsEmbeddedSettingsPage' "$settings_qml" \
  || fail "official settings should embed full migrated section components when curated cards are not enough"

for source in \
  'modules/settings/BackgroundConfig.qml' \
  'modules/settings/DesktopWidgetsConfig.qml' \
  'modules/settings/ExtrasConfig.qml'; do
  grep -q "$source" "$settings_qml" \
    || fail "official settings should keep full section coverage from $source"
done

if grep -q 'background.wallpaper.enableAnimation' "$settings_qml"; then
  fail "wallpaper animation should use the existing background.enableAnimation key"
fi

# The General > Window sub-tab (and its settingsUi.launchMode combo) was removed
# from ryokuSettings.qml; centered is the only supported mode for the new UI.
# The Config schema still exposes launchMode for ryoku-shell to read.

grep -q 'property string launchMode: "centered"' "$config_schema" \
  || fail "config schema should default settings launch mode to centered"

grep -q 'property bool followTheme: false' "$config_schema" \
  || fail "config schema should persist focus-ring theme-follow preference"

for rules in "$window_rules" "$default_window_rules"; do
  grep -q 'Ryoku Settings' "$rules" \
    || fail "$rules should match the settings window"
  grep -q 'open-floating true' "$rules" \
    || fail "$rules should open the settings as a floating window"
  grep -q 'draw-border-with-background false' "$rules" \
    || fail "$rules should not let compositor decorations tint the transparent settings frame"
  awk '/Ryoku Settings/,/^}/ { if ($0 ~ /focus-ring/) focus=1; if ($0 ~ /border/) border=1 } END { exit (focus && border) ? 0 : 1 }' "$rules" \
    || fail "$rules should disable compositor focus ring and border for the settings"
done

echo "PASS: official Ryoku settings is wired"
