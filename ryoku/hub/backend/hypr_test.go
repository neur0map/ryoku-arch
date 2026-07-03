package main

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

// genLua should only emit what diverges from the shipped defaults: an untouched
// override -> no hl.config block, base modules stay in charge.
func TestGenLuaDefaultsAreEmpty(t *testing.T) {
	out := genLua(defaultOverrides(), true)
	if strings.Contains(out, "hl.config(") {
		t.Errorf("default overrides emitted a config block:\n%s", out)
	}
	if strings.Contains(out, "hl.window_rule(") || strings.Contains(out, "hl.bind(") {
		t.Errorf("default overrides emitted rules/binds:\n%s", out)
	}
}

func TestGenLuaEmitsChangedLeavesOnly(t *testing.T) {
	o := defaultOverrides()
	o.Appearance.Rounding = 24
	o.Appearance.GapsIn = 12
	out := genLua(o, true)
	if !strings.Contains(out, "rounding = 24") {
		t.Errorf("rounding override missing:\n%s", out)
	}
	if !strings.Contains(out, "gaps_in = 12") {
		t.Errorf("gaps_in override missing:\n%s", out)
	}
	// border_size untouched -> must not appear.
	if strings.Contains(out, "border_size") {
		t.Errorf("unchanged border_size was emitted:\n%s", out)
	}
}

// border colours only land when "follow wallpaper" is off, in the rgb() form
// Hyprland wants.
func TestGenLuaBorderColours(t *testing.T) {
	o := defaultOverrides()
	if strings.Contains(genLua(o, true), "col.active_border") {
		t.Error("borders emitted while following wallpaper")
	}
	o.Appearance.ActiveBorder = "#ff6a3d"
	out := genLua(o, false)
	if !strings.Contains(out, `["col.active_border"] = "rgb(ff6a3d)"`) {
		t.Errorf("active border not in rgb() form:\n%s", out)
	}
}

func TestGenLuaAnimationsToggle(t *testing.T) {
	o := defaultOverrides()
	o.Appearance.Animations = false
	if !strings.Contains(genLua(o, true), "animations = { enabled = false }") {
		t.Error("animations disable not emitted")
	}
}

func TestGenLuaTouchpadHyphenKey(t *testing.T) {
	o := defaultOverrides()
	o.Input.TapToClick = false
	if !strings.Contains(genLua(o, true), `["tap-to-click"] = false`) {
		t.Errorf("hyphenated touchpad key not bracket-quoted:\n%s", genLua(o, true))
	}
}

func TestGenLuaWindowRuleAndKeybind(t *testing.T) {
	o := defaultOverrides()
	o.WindowRules = []WindowRule{{Class: "Spotify", Action: "float"}}
	o.WindowRules = append(o.WindowRules, WindowRule{Title: "Picture in picture", Action: "size", Value: "640x360"})
	o.Keybinds = []Keybind{{Keys: "SUPER + J", Action: "exec", Value: "kitty"}}
	out := genLua(o, true)
	if !strings.Contains(out, `match = { class = "Spotify" }, float = true`) {
		t.Errorf("float rule malformed:\n%s", out)
	}
	if !strings.Contains(out, "size = { 640, 360 }") {
		t.Errorf("size rule malformed:\n%s", out)
	}
	if !strings.Contains(out, `hl.bind("SUPER + J", hl.dsp.exec_cmd("kitty"))`) {
		t.Errorf("exec keybind malformed:\n%s", out)
	}
}

// rule with no match -> dropped (class-of-everything would be a footgun). exec
// bind with no command -> dropped.
func TestGenLuaDropsIncomplete(t *testing.T) {
	o := defaultOverrides()
	o.WindowRules = []WindowRule{{Action: "float"}}
	o.Keybinds = []Keybind{{Keys: "SUPER + K", Action: "exec", Value: ""}}
	out := genLua(o, true)
	if strings.Contains(out, "hl.window_rule(") {
		t.Errorf("matchless rule was emitted:\n%s", out)
	}
	if strings.Contains(out, "hl.bind(") {
		t.Errorf("commandless exec bind was emitted:\n%s", out)
	}
}

func TestGenLuaCursorStartHook(t *testing.T) {
	o := defaultOverrides()
	o.Cursor = Cursor{Theme: "Bibata-Modern-Classic", Size: 32}
	out := genLua(o, true)
	if !strings.Contains(out, `hl.on("hyprland.start"`) {
		t.Errorf("cursor change did not register a start hook:\n%s", out)
	}
	if !strings.Contains(out, "hyprctl setcursor Bibata-Modern-Classic 32") {
		t.Errorf("setcursor command missing:\n%s", out)
	}
}

func TestLuaStrEscapes(t *testing.T) {
	if got := luaStr(`a"b\c`); got != `"a\"b\\c"` {
		t.Errorf("luaStr = %s", got)
	}
}

func TestParseWxH(t *testing.T) {
	for _, in := range []string{"640x360", "640 360", "640,360"} {
		if w, h := parseWxH(in); w != 640 || h != 360 {
			t.Errorf("parseWxH(%q) = %d,%d", in, w, h)
		}
	}
}

// loadOverrides overlays a partial store on the defaults: missing fields keep
// the default, they don't zero out.
func TestParseOverridesPartialKeepsDefaults(t *testing.T) {
	o, err := parseOverrides(`{"appearance":{"rounding":20}}`)
	if err != nil {
		t.Fatal(err)
	}
	if o.Appearance.Rounding != 20 {
		t.Errorf("rounding = %d, want 20", o.Appearance.Rounding)
	}
	if o.Appearance.BorderSize != 3 {
		t.Errorf("borderSize = %d, want default 3", o.Appearance.BorderSize)
	}
	if o.Input.KbLayout != "us" {
		t.Errorf("kbLayout = %q, want default us", o.Input.KbLayout)
	}
}

// liveLua must emit every appearance/input leaf explicitly (so eval can reset
// a value back to the default, not just push it the other way), include the
// cursor, and parse as valid Lua.
func TestLiveLuaIsFullAndParses(t *testing.T) {
	lua := liveLua(defaultOverrides())
	for _, want := range []string{
		"gaps_in = 8", "rounding = 16", "active_opacity = 0.96",
		"kb_layout = \"us\"", "follow_mouse = 2",
		"[\"tap-to-click\"] = true", "animations = { enabled = true }",
		"setcursor Bibata-Modern-Ice 24",
	} {
		if !strings.Contains(lua, want) {
			t.Errorf("liveLua missing %q:\n%s", want, lua)
		}
	}
	luac, err := exec.LookPath("luac")
	if err != nil {
		t.Skip("luac not available")
	}
	cmd := exec.Command(luac, "-p", "-")
	cmd.Stdin = strings.NewReader(lua)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("liveLua does not parse: %v\n%s\n%s", err, out, lua)
	}
}

// genConfig writes follow_mouse into settings.lua only when it diverges from the
// base config (input.lua ships follow_mouse = 2). picking "Normal" (1) in the Hub
// must emit the override so hover-to-focus actually applies; the default must not.
func TestGenConfigFollowMouseOverride(t *testing.T) {
	if got := genConfig(defaultOverrides(), true); strings.Contains(got, "follow_mouse") {
		t.Errorf("default follow_mouse must emit no override, got:\n%s", got)
	}
	o := defaultOverrides()
	o.Input.FollowMouse = 1
	if got := genConfig(o, true); !strings.Contains(got, "follow_mouse = 1") {
		t.Errorf("follow_mouse = 1 must be written so hover-to-focus takes effect, got:\n%s", got)
	}
}

// genAnimBlock: user beziers go before the animations that reference them,
// bezier/style omitted when empty. liveLua includes the block so a preview
// actually plays the curves + animations.
func TestGenAnimBlock(t *testing.T) {
	if genAnimBlock(defaultOverrides()) != "" {
		t.Error("empty anim produced output")
	}
	o := defaultOverrides()
	o.Anim.Curves = []AnimCurve{{Name: "ryokuBloom", X0: 0.2, Y0: 1.3, X1: 0.3, Y1: 1.0}}
	o.Anim.Items = []AnimItem{
		{Leaf: "windowsIn", Enabled: true, Speed: 4, Bezier: "ryokuBloom", Style: "popin 70%"},
		{Leaf: "fade", Enabled: false, Speed: 2},
	}
	out := genAnimBlock(o)
	if !strings.Contains(out, `hl.curve("ryokuBloom", { type = "bezier", points = { { 0.2, 1.3 }, { 0.3, 1.0 } } })`) {
		t.Errorf("curve malformed:\n%s", out)
	}
	if !strings.Contains(out, `hl.animation({ leaf = "windowsIn", enabled = true, speed = 4.0, bezier = "ryokuBloom", style = "popin 70%" })`) {
		t.Errorf("animation malformed:\n%s", out)
	}
	if !strings.Contains(out, `hl.animation({ leaf = "fade", enabled = false, speed = 2.0 })`) {
		t.Errorf("fade should omit empty bezier/style:\n%s", out)
	}
	if !strings.Contains(liveLua(o), "hl.curve(") {
		t.Error("liveLua must include curves for preview")
	}
}

// genGesture only emits when workspace swipe is on, fingers clamped to >= 3.
func TestGenGesture(t *testing.T) {
	if genGesture(defaultOverrides()) != "" {
		t.Error("default emitted a gesture")
	}
	o := defaultOverrides()
	o.Input.WorkspaceSwipe = true
	o.Input.SwipeFingers = 4
	want := "hl.gesture({ fingers = 4, direction = \"horizontal\", action = \"workspace\" })\n"
	if genGesture(o) != want {
		t.Errorf("gesture = %q, want %q", genGesture(o), want)
	}
	o.Input.SwipeFingers = 2
	if !strings.Contains(genGesture(o), "fingers = 3") {
		t.Errorf("fingers should clamp to >= 3: %q", genGesture(o))
	}
}

// once input settings were saved, all three kb_* keys are pinned even at their
// defaults, so a non-us keyboard.lua can no longer silently win over the UI.
// every other key keeps the diff-against-defaults behavior.
func TestGenConfigPinsKbAfterInputSave(t *testing.T) {
	o := defaultOverrides()
	o.inputSaved = true
	out := genConfig(o, true)
	for _, want := range []string{`kb_layout = "us"`, `kb_variant = ""`, `kb_options = ""`} {
		if !strings.Contains(out, want) {
			t.Errorf("saved input must pin %s:\n%s", want, out)
		}
	}
	if strings.Contains(out, "repeat_rate") {
		t.Errorf("unchanged repeat_rate was emitted:\n%s", out)
	}
}

// a snapshot arriving through save/preview counts as saved input, so the very
// first save already pins the kb_* keys.
func TestParseOverridesMarksInputSaved(t *testing.T) {
	o, err := parseOverrides(`{}`)
	if err != nil {
		t.Fatal(err)
	}
	if !o.inputSaved {
		t.Error("parseOverrides did not mark input as saved")
	}
}

// storeHasInput: only a store that actually carries an input section counts,
// so a legacy or foreign store does not flip the kb pinning on.
func TestStoreHasInput(t *testing.T) {
	for s, want := range map[string]bool{
		`{"input":{"kbLayout":"fr"}}`: true,
		`{"input":{}}`:                true,
		`{"appearance":{}}`:           false,
		`{"input":null}`:              false,
		`not json`:                    false,
	} {
		if got := storeHasInput([]byte(s)); got != want {
			t.Errorf("storeHasInput(%s) = %t, want %t", s, got, want)
		}
	}
}

// parseXkbVariants filters the "! variant" block to one layout; a layout field
// listing several codes matches each of them.
func TestParseXkbVariants(t *testing.T) {
	lst := "! variant\n" +
		"  azerty          fr: French (AZERTY)\n" +
		"  nodeadkeys      fr: French (no dead keys)\n" +
		"  wang            be: Belgian (Wang 724 AZERTY)\n" +
		"  shared          fr,be: Shared variant\n" +
		"\n" +
		"! option\n" +
		"  grp             Switching to another layout\n"
	p := filepath.Join(t.TempDir(), "base.lst")
	if err := os.WriteFile(p, []byte(lst), 0o644); err != nil {
		t.Fatal(err)
	}
	got := parseXkbVariants(p, "fr")
	if len(got) != 3 {
		t.Fatalf("fr variants = %v, want 3 entries", got)
	}
	if got[0]["code"] != "azerty" || got[0]["name"] != "French (AZERTY)" {
		t.Errorf("first fr variant = %v", got[0])
	}
	if got[2]["code"] != "shared" {
		t.Errorf("comma-separated layout list not matched: %v", got[2])
	}
	if be := parseXkbVariants(p, "be"); len(be) != 2 {
		t.Errorf("be variants = %v, want wang + shared", be)
	}
	// the option block must not leak in, and an unknown layout yields nothing.
	if xx := parseXkbVariants(p, "grp"); len(xx) != 0 {
		t.Errorf("option block leaked into variants: %v", xx)
	}
}

// genLayerRule needs namespace + a known action; ignorealpha carries a value.
func TestGenLayerRule(t *testing.T) {
	if genLayerRule(0, LayerRule{Action: "blur"}) != "" {
		t.Error("namespaceless layer rule was emitted")
	}
	got := genLayerRule(0, LayerRule{Namespace: "sidebar", Action: "blur"})
	if got != `hl.layer_rule({ name = "ryoku-layer-1", match = { namespace = "sidebar" }, blur = true })`+"\n" {
		t.Errorf("blur layer rule malformed: %q", got)
	}
	got = genLayerRule(1, LayerRule{Namespace: "bar", Action: "ignorealpha", Value: "0.3"})
	if !strings.Contains(got, "ignore_alpha = 0.3") {
		t.Errorf("ignorealpha value missing: %q", got)
	}
}
