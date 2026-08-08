package doctor

import (
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"ryoku-cli/internal/keyboard"
	"ryoku-cli/internal/sys"
)

// ---- reconcilers: the keyboard layout, on every screen that asks for one ------
//
// The four layers, and why the boot one traps people, are described in
// internal/keyboard. These two reconcilers cover the two directions: adopting
// the layout the installer was told about into a desktop still on the shipped
// default, and reporting when the layers have drifted apart afterwards.

var keymapLayoutRe = regexp.MustCompile(`kb_layout\s*=\s*"([^"]*)"`)

// hyprLayout reads the session's primary layout from the generated settings.lua.
// The value can carry a second layout ("fr,us"); the first is the one a login
// screen and a boot prompt need, since neither can switch.
func hyprLayout() string {
	b, err := os.ReadFile(filepath.Join(configHome(), "hypr", "settings.lua"))
	if err != nil {
		return ""
	}
	m := keymapLayoutRe.FindSubmatch(b)
	if m == nil {
		return ""
	}
	return strings.TrimSpace(strings.SplitN(string(m[1]), ",", 2)[0])
}

func reconcileKeymap(checkOnly bool) recResult {
	layout := hyprLayout()
	if layout == "" {
		return okRes("no session keyboard layout recorded yet")
	}
	km := keyboard.ConsoleKeymap()
	// Compared in xkb terms, so a console keymap that spells the same layout
	// differently (uk for gb) is not reported as drift.
	consoleDrifted := km != "" && keyboard.ConsoleAsXkb(km) != layout
	stale, imgPath := keyboard.BootStale()

	switch {
	case consoleDrifted && stale:
		return warnRes("console keymap is %q but the session uses %q, and the boot image predates %s so the disk passphrase prompt is older still",
			km, layout, keyboard.VconsolePath).
			withFix("ryoku keyboard apply")
	case consoleDrifted:
		if checkOnly {
			return wouldRes("console keymap is %q but the session uses %q, so the login screen and TTYs disagree with the desktop", km, layout).
				withFix("ryoku keyboard apply")
		}
		if err := keyboard.ApplySystem(keyboard.Layout{Layout: layout}); err != nil {
			return warnRes("console keymap is %q but the session uses %q", km, layout).
				withFix("ryoku keyboard apply")
		}
		return fixedRes("set the login screen and TTY keymap to %q; the disk passphrase prompt follows after `ryoku keyboard apply`", layout)
	case stale:
		return warnRes("%s predates %s, so the disk passphrase prompt still uses the keymap baked in when it was built",
			filepath.Base(imgPath), keyboard.VconsolePath).
			withFix("ryoku keyboard apply")
	}
	return okRes("keyboard layout %q matches on the session, login screen, console, and boot prompt", layout)
}

// ---- reconciler: adopt the keyboard the installer was told about --------------

// keyboardSeedMarker records that the one-time adoption has run, so a later
// deliberate pick in Ryoku Settings is never quietly undone on the next doctor.
func keyboardSeedMarker() string {
	return filepath.Join(sys.Xdg("XDG_STATE_HOME", ".local/state"), "ryoku", "migrations", "keyboard-layout-seed")
}

// hyprGetKbLayout pulls input.kbLayout out of a saved hypr.json.
func hyprGetKbLayout(raw string) (string, bool) {
	var o struct {
		Input struct {
			KbLayout *string `json:"kbLayout"`
		} `json:"input"`
	}
	if json.Unmarshal([]byte(raw), &o) != nil || o.Input.KbLayout == nil {
		return "", false
	}
	return *o.Input.KbLayout, true
}

// hyprSetKbLayout rewrites input.kbLayout, leaving every other key untouched.
func hyprSetKbLayout(raw, layout string) (string, error) {
	var doc map[string]any
	if err := json.Unmarshal([]byte(raw), &doc); err != nil {
		return "", err
	}
	input, _ := doc["input"].(map[string]any)
	if input == nil {
		input = map[string]any{}
		doc["input"] = input
	}
	input["kbLayout"] = layout
	out, err := json.MarshalIndent(doc, "", "  ")
	if err != nil {
		return "", err
	}
	return string(out), nil
}

// reconcileKeyboardSeed adopts the layout the machine already records when the
// desktop is still on the shipped default. A keyboard cannot report its own
// legends, so installing on AZERTY and finding the desktop on QWERTY is the
// normal first boot; this closes that gap once.
func reconcileKeyboardSeed(checkOnly bool) recResult {
	marker := keyboardSeedMarker()
	if sys.Exists(marker) {
		return okRes("keyboard layout already adopted once")
	}
	mark := func() {
		if checkOnly {
			return
		}
		_ = os.MkdirAll(filepath.Dir(marker), 0o755)
		_ = os.WriteFile(marker, []byte("done\n"), 0o644)
	}
	hyprJSON := filepath.Join(sys.ConfigHome(), "ryoku", "hypr.json")
	if !sys.Has("ryoku-hub") || !sys.Exists(hyprJSON) {
		mark()
		return okRes("no saved hypr input to seed a layout into")
	}
	cur, ok := hyprGetKbLayout(readFileSafe(hyprJSON))
	// Only the untouched shipped default is adopted over. Anything else is a
	// choice, including a deliberate "us".
	if !ok || cur != "us" {
		mark()
		return okRes("keyboard layout is a deliberate choice; leaving it")
	}
	got := keyboard.Detect(keyboard.X11Layout(), keyboard.ConsoleKeymap(), keyboard.SystemLocale())
	if got.Layout == "" || got.Layout == "us" {
		mark()
		return okRes("nothing on this system points at a non-US keyboard")
	}
	if checkOnly {
		return wouldRes("%s says this is a %q keyboard but the desktop is still on us", got.Source, got.Layout).
			withFix("ryoku doctor")
	}
	raw, err := sys.RunOut("ryoku-hub", "hypr", "get")
	if err != nil {
		return warnRes("could not read hypr settings to adopt the layout: %v", err)
	}
	fixed, err := hyprSetKbLayout(raw, got.Layout)
	if err != nil {
		return failRes("could not update hypr settings: %v", err)
	}
	if err := sys.Run("ryoku-hub", "hypr", "save", fixed); err != nil {
		return failRes("could not save the detected layout: %v", err).withFix("ryoku doctor")
	}
	mark()
	return fixedRes("adopted the %q keyboard layout from %s; run `ryoku keyboard apply` to put it on the login screen and boot prompt too", got.Layout, got.Source)
}
