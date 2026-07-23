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
	o.Appearance.GapsIn = 20
	out := genLua(o, true)
	if !strings.Contains(out, "rounding = 24") {
		t.Errorf("rounding override missing:\n%s", out)
	}
	if !strings.Contains(out, "gaps_in = 20") {
		t.Errorf("gaps_in override missing:\n%s", out)
	}
	// border_size untouched -> must not appear.
	if strings.Contains(out, "border_size") {
		t.Errorf("unchanged border_size was emitted:\n%s", out)
	}
}

// the expanded option set follows the same diff rule: only divergences land,
// nested subsections only materialise when a leaf inside them diverged.
func TestGenLuaEmitsNewLeaves(t *testing.T) {
	o := defaultOverrides()
	o.Appearance.DimInactive = true
	o.Appearance.RoundingPower = 2.5
	o.Appearance.BlurVibrancy = 0.3
	o.Appearance.GlowEnabled = true
	o.Appearance.SnapEnabled = true
	o.Input.LeftHanded = true
	o.Input.MiddleClickPaste = false
	o.Input.SwipeDistance = 420
	o.Cursor.InactiveTimeout = 5
	out := genLua(o, true)
	for _, want := range []string{
		"dim_inactive = true", "rounding_power = 2.5", "vibrancy = 0.3",
		"glow = { enabled = true }", "snap = { enabled = true }",
		"left_handed = true", "misc = { middle_click_paste = false }",
		"gestures = { workspace_swipe_distance = 420 }",
		"cursor = { inactive_timeout = 5 }",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q:\n%s", want, out)
		}
	}
	for _, not := range []string{"dim_strength", "noise", "render_power", "tap_and_drag", "scroll_factor", "hide_on_key_press"} {
		if strings.Contains(out, not) {
			t.Errorf("unchanged %q was emitted:\n%s", not, out)
		}
	}
}

// a store written before the option expansion misses every new field; the
// on-disk overlay must keep the new defaults, so a regenerated settings.lua
// stays diff-clean for an untouched system. (parseOverrides would pin kb_*,
// that path is the save flow; upgrades go through loadOverrides.)
func TestLoadOverridesOldStoreKeepsNewDefaults(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)
	old := `{"appearance":{"gapsIn":12,"gapsOut":18,"borderSize":2,"rounding":0,` +
		`"activeOpacity":1,"inactiveOpacity":0.94,"blurEnabled":true,"blurSize":4,` +
		`"blurPasses":1,"shadowEnabled":true,"shadowRange":45,"animations":true,` +
		`"layout":"dwindle","activeBorder":"#e0563b","inactiveBorder":"#313a4d"},` +
		`"cursor":{"theme":"Bibata-Modern-Ice","size":24}}`
	if err := os.MkdirAll(filepath.Join(dir, "ryoku"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(dir, "ryoku", "hypr.json"), []byte(old), 0o644); err != nil {
		t.Fatal(err)
	}
	o := loadOverrides()
	if o.Appearance.RoundingPower != 4 || o.Appearance.BlurVibrancy != 0.17 || !o.Appearance.ResizeOnBorder {
		t.Errorf("new appearance defaults lost: %+v", o.Appearance)
	}
	if !o.Input.TapAndDrag || !o.Input.MiddleClickPaste || o.Input.SwipeDistance != 300 {
		t.Errorf("new input defaults lost: %+v", o.Input)
	}
	if out := genLua(o, true); strings.Contains(out, "hl.config") {
		t.Errorf("legacy store produced config divergence:\n%s", out)
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

// the touchpad tap key is snake_case in the hl API (the conf syntax's
// tap-to-click is rejected by the Lua config and would kill the whole block).
func TestGenLuaTouchpadTapKey(t *testing.T) {
	o := defaultOverrides()
	o.Input.TapToClick = false
	if !strings.Contains(genLua(o, true), `tap_to_click = false`) {
		t.Errorf("touchpad tap key not emitted as tap_to_click:\n%s", genLua(o, true))
	}
}

// legacy pretty-action keys map onto the real hl field names; a bad mapping
// here errors inside settings.lua and silently disables everything after it.
func TestGenWindowRuleFieldNames(t *testing.T) {
	for action, want := range map[string]string{
		"noblur":          "no_blur = true",
		"noshadow":        "no_shadow = true",
		"noborder":        "border_size = 0",
		"norounding":      "rounding = 0",
		"nodim":           "no_dim = true",
		"noanim":          "no_anim = true",
		"nofocus":         "no_focus = true",
		"stayfocused":     "stay_focused = true",
		"keepaspectratio": "keep_aspect_ratio = true",
		"opaque":          "opaque = true",
		"xray":            "xray = true",
		"pseudo":          "pseudo = true",
		"maximize":        "maximize = true",
		"immediate":       "immediate = true",
	} {
		got := genWindowRule(0, WindowRule{Class: "x", Action: action})
		if !strings.Contains(got, want) {
			t.Errorf("action %q: got %q, want it to carry %q", action, got, want)
		}
	}
	if got := genWindowRule(0, WindowRule{Class: "x", Action: "idleinhibit", Value: "focus"}); !strings.Contains(got, `idle_inhibit = "focus"`) {
		t.Errorf("idleinhibit rule malformed: %q", got)
	}
	if got := genWindowRule(0, WindowRule{Class: "x", Action: "idleinhibit", Value: "bogus"}); !strings.Contains(got, `idle_inhibit = "always"`) {
		t.Errorf("idleinhibit bad value not clamped: %q", got)
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
	if o.Appearance.BorderSize != 2 {
		t.Errorf("borderSize = %d, want default 2", o.Appearance.BorderSize)
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
		"gaps_in = 12", "rounding = 0", "rounding_power = 4.0", "active_opacity = 1.0",
		"dim_inactive = false", "vibrancy = 0.17", "render_power = 4",
		"glow = { enabled = false", "resize_on_border = true", "snap = { enabled = false }",
		"kb_layout = \"us\"", "follow_mouse = 2", "left_handed = false",
		"tap_to_click = true", "tap_and_drag = true", "scroll_factor = 1.0",
		"cursor = { inactive_timeout = 0", "middle_click_paste = true",
		"workspace_swipe_invert = true", "animations = { enabled = true }",
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

// genMotion: the wobble toggle defines its overshoot curve and drives windowsMove.
// off it stays out of settings.lua, but a live preview resets the leaf so the
// toggle can be switched back off.
func TestGenMotionWobble(t *testing.T) {
	if genMotion(defaultOverrides(), false) != "" {
		t.Errorf("default motion must be empty in settings.lua, got:\n%s", genMotion(defaultOverrides(), false))
	}
	o := defaultOverrides()
	o.Appearance.WobblyWindows = true
	on := genMotion(o, false)
	if !strings.Contains(on, `hl.curve("ryokuWobble"`) {
		t.Errorf("wobble must define its curve:\n%s", on)
	}
	if !strings.Contains(on, `hl.animation({ leaf = "windowsMove", enabled = true, speed = 5, bezier = "ryokuWobble" })`) {
		t.Errorf("wobble must drive windowsMove:\n%s", on)
	}
	off := genMotion(defaultOverrides(), true)
	if !strings.Contains(off, `leaf = "windowsMove", enabled = true, speed = 3.2, bezier = "ryokuSettle"`) {
		t.Errorf("preview must reset windowsMove when wobble is off:\n%s", off)
	}
}

// genMotion window style: only slide/gnomed diverge; the default pop writes
// nothing to settings.lua and the live preview restates the base popin so the
// choice can reset.
func TestGenMotionWindowStyle(t *testing.T) {
	o := defaultOverrides()
	o.Appearance.WindowStyle = "slide"
	got := genMotion(o, false)
	if !strings.Contains(got, `leaf = "windowsIn", enabled = true, speed = 3.8, bezier = "ryokuBloom", style = "slide"`) {
		t.Errorf("slide must set windowsIn style:\n%s", got)
	}
	if !strings.Contains(got, `leaf = "windowsOut", enabled = true, speed = 2.4, bezier = "ryokuSettle", style = "slide"`) {
		t.Errorf("slide must set windowsOut style:\n%s", got)
	}
	if strings.Contains(genMotion(defaultOverrides(), false), "windowsIn") {
		t.Error("default pop must not pin windowsIn in settings.lua")
	}
	if !strings.Contains(genMotion(defaultOverrides(), true), `style = "popin 78%"`) {
		t.Error("preview must restate the base popin so the style can reset")
	}
}

// borderAngleHyprSpeed maps friendly 1..10 to Hyprland deciseconds (higher there
// is slower), inverted so a bigger slider value spins faster, and clamps.
func TestBorderAngleHyprSpeed(t *testing.T) {
	for in, want := range map[float64]float64{1: 100, 3: 80, 10: 10, 0: 100, 99: 10} {
		if got := borderAngleHyprSpeed(in); got != want {
			t.Errorf("borderAngleHyprSpeed(%v) = %v, want %v", in, got, want)
		}
	}
}

// genAnimatedBorder: off is silent in settings.lua; on with fixed colours writes
// a gradient active border as a colors table (a string is rejected by the hl API)
// plus the looping sweep, and genConfig drops its solid active border so the
// gradient wins.
func TestGenAnimatedBorderFixed(t *testing.T) {
	if genAnimatedBorder(defaultOverrides(), false, false) != "" {
		t.Error("animated border off must be silent in settings.lua")
	}
	o := defaultOverrides()
	o.Appearance.AnimatedBorder = true
	got := genAnimatedBorder(o, false, false)
	if !strings.Contains(got, `["col.active_border"] = { colors = { "rgb(e0563b)", "rgb(313a4d)" }, angle = 45 }`) {
		t.Errorf("fixed animated border must be a colors table:\n%s", got)
	}
	if !strings.Contains(got, `leaf = "borderangle", enabled = true, speed = 80.0, bezier = "linear", style = "loop"`) {
		t.Errorf("animated border must loop the sweep:\n%s", got)
	}
	if strings.Contains(genConfig(o, false), "col.active_border") {
		t.Errorf("genConfig must drop the solid active border when animated:\n%s", genConfig(o, false))
	}
	if !strings.Contains(genConfig(o, false), "col.inactive_border") {
		t.Error("genConfig must still set the fixed inactive border")
	}
}

// genAnimatedBorder while colours follow the wallpaper reads the live wallust
// accents at load time, so the sweep re-themes on reload; a preview turning it
// off stops the sweep and restores a solid border.
func TestGenAnimatedBorderFollow(t *testing.T) {
	o := defaultOverrides()
	o.Appearance.AnimatedBorder = true
	got := genAnimatedBorder(o, true, false)
	if !strings.Contains(got, "hypr-colors.lua") || !strings.Contains(got, "colors = {") {
		t.Errorf("following animated border must read wallust accents into a gradient:\n%s", got)
	}
	if !strings.Contains(got, `style = "loop"`) {
		t.Errorf("following animated border must loop:\n%s", got)
	}
	off := genAnimatedBorder(defaultOverrides(), true, true)
	if !strings.Contains(off, "enabled = false") || !strings.Contains(off, "hypr-colors.lua") {
		t.Errorf("preview off must stop the sweep and restore the solid border:\n%s", off)
	}
}

// genLua and liveLua must stay valid Lua with the motion and border toggles on,
// across follow-wallpaper and fixed colours.
func TestMotionTogglesParse(t *testing.T) {
	luac, err := exec.LookPath("luac")
	if err != nil {
		t.Skip("luac not available")
	}
	o := defaultOverrides()
	o.Appearance.WobblyWindows = true
	o.Appearance.WindowStyle = "gnomed"
	o.Appearance.AnimatedBorder = true
	for _, lua := range []string{genLua(o, false), genLua(o, true), liveLua(o)} {
		cmd := exec.Command(luac, "-p", "-")
		cmd.Stdin = strings.NewReader(lua)
		if out, err := cmd.CombinedOutput(); err != nil {
			t.Fatalf("motion toggles do not parse: %v\n%s\n%s", err, out, lua)
		}
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
	// dim_around is a bool in the hl API; the stored value must not leak in.
	got = genLayerRule(2, LayerRule{Namespace: "bar", Action: "dimaround", Value: "0.4"})
	if !strings.Contains(got, "dim_around = true") {
		t.Errorf("dimaround not emitted as bool: %q", got)
	}
	// layers have no shadow effect anymore; a stored legacy rule must vanish
	// rather than emit a field the runtime rejects.
	if got := genLayerRule(3, LayerRule{Namespace: "bar", Action: "noshadow"}); got != "" {
		t.Errorf("legacy noshadow layer rule emitted: %q", got)
	}
	got = genLayerRule(4, LayerRule{Namespace: "bar", Action: "xray"})
	if !strings.Contains(got, "xray = true") {
		t.Errorf("xray layer rule malformed: %q", got)
	}
	got = genLayerRule(5, LayerRule{Namespace: "osd", Action: "abovelock"})
	if !strings.Contains(got, "above_lock = true") {
		t.Errorf("abovelock layer rule malformed: %q", got)
	}
}

// genPlugins: an untouched system enables no plugin, so settings.lua carries no
// hl.plugin.load, no loaded-guard helper, and no scrolling core config.
func TestGenPluginsDefaultsAreEmpty(t *testing.T) {
	out := genLua(defaultOverrides(), true)
	for _, not := range []string{"hl.plugin.load", "ryoku_plugin_loaded", "scrolling = {"} {
		if strings.Contains(out, not) {
			t.Errorf("default config emitted %q:\n%s", not, out)
		}
	}
}

// dynamic-cursors: the dashed section is bracket-quoted, shake nests, the load
// uses the dashed .so name, and the block is wrapped in pcall so a failed load
// can't abort settings.lua. The old hl.get_loaded_plugins guard (which does not
// exist in the real hl API and broke the whole config) must never be emitted.
func TestGenPluginsDynamicCursors(t *testing.T) {
	t.Setenv("HOME", t.TempDir()) // hermetic: no checkout ~/.local plugin, so /usr/lib
	o := defaultOverrides()
	o.Plugins.DynamicCursors.Enabled = true
	out := genLua(o, true)
	for _, want := range []string{
		"pcall(function()",
		`hl.plugin.load("/usr/lib/hyprland/plugins/dynamic-cursors.so")`,
		`hl.config({ plugin = { dynamic_cursors = { enabled = true, mode = "tilt", shake = { enabled = true, base = 4.0 } } } })`,
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q:\n%s", want, out)
		}
	}
	for _, not := range []string{"get_loaded_plugins", "ryoku_plugin_loaded"} {
		if strings.Contains(out, not) {
			t.Errorf("must not emit %q (not in the real hl API):\n%s", not, out)
		}
	}
}

// hyprbars: config uses the source key names (bar_height / bar_text_size /
// bar_blur) and the default button set is added through the plugin's Lua API
// inside the guard.
func TestGenPluginsHyprbarsButtons(t *testing.T) {
	o := defaultOverrides()
	o.Plugins.Hyprbars.Enabled = true
	out := genLua(o, true)
	for _, want := range []string{
		`hl.config({ plugin = { hyprbars = { enabled = true, bar_height = 26, bar_text_size = 11, bar_blur = true } } })`,
		`hl.plugin.hyprbars.add_button({`,
		`action = "hyprctl dispatch killactive"`,
		`action = "hyprctl dispatch fullscreen 1"`,
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q:\n%s", want, out)
		}
	}
	o.Plugins.Hyprbars.Buttons = false
	if strings.Contains(genLua(o, true), "add_button") {
		t.Error("buttons off must not emit add_button")
	}
}

// hyprfocus: the keys the plugin at the 0.55.4 pin actually registers (verified
// live via hyprctl getoption) are mode / fade_opacity / bounce_strength /
// slide_height, with no `enable` key (loading the .so enables it). A newer
// upstream commit renamed these, but our package builds the 0.55.4-matched
// commit, so these are the ones that must be emitted.
func TestGenPluginsHyprfocusKeys(t *testing.T) {
	t.Setenv("HOME", t.TempDir()) // hermetic: no checkout ~/.local plugin, so /usr/lib
	o := defaultOverrides()
	o.Plugins.Hyprfocus.Enabled = true
	o.Plugins.Hyprfocus.Mode = "bounce"
	out := genLua(o, true)
	for _, want := range []string{
		`hl.plugin.load("/usr/lib/hyprland/plugins/hyprfocus.so")`,
		`mode = "bounce"`, `fade_opacity = 0.8`, `bounce_strength = 0.95`, `slide_height = 20.0`,
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q:\n%s", want, out)
		}
	}
	for _, not := range []string{"enable = true", "keyboard_focus_animation", "shrink_percentage"} {
		if strings.Contains(out, not) {
			t.Errorf("stale hyprfocus key %q emitted:\n%s", not, out)
		}
	}
}

// hyprglass: tint is a 0x ARGB literal, preset and float knobs pass through.
func TestGenPluginsHyprglass(t *testing.T) {
	o := defaultOverrides()
	o.Plugins.Hyprglass.Enabled = true
	out := genLua(o, true)
	for _, want := range []string{
		`hl.config({ plugin = { hyprglass = { enabled = 1, default_preset = "clear", blur_strength = 2.0, glass_opacity = 1.0, tint_color = 0x8899aa22, brightness = 1.0, default_theme = "dark" } } })`,
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q:\n%s", want, out)
		}
	}
}

// imgborders: sizes/insets are required strings; image passes through.
func TestGenPluginsImgborders(t *testing.T) {
	o := defaultOverrides()
	o.Plugins.Imgborders.Enabled = true
	o.Plugins.Imgborders.Image = "/home/x/b.png"
	out := genLua(o, true)
	want := `hl.config({ plugin = { imgborders = { enabled = true, image = "/home/x/b.png", sizes = "8,8,8,8", insets = "0,0,0,0", scale = 1.0, smooth = true, blur = false } } })`
	if !strings.Contains(out, want) {
		t.Errorf("missing %q:\n%s", want, out)
	}
}

// pluginSoPath prefers a checkout's ~/.local .so over the packaged /usr/lib one,
// so `ryoku update` on a dev/tester box loads what deploy.sh just built.
func TestGenPluginsPrefersUserPath(t *testing.T) {
	home := t.TempDir()
	t.Setenv("HOME", home)
	so := filepath.Join(home, ".local", "lib", "hyprland", "plugins", "dynamic-cursors.so")
	if err := os.MkdirAll(filepath.Dir(so), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(so, []byte{0}, 0o644); err != nil {
		t.Fatal(err)
	}
	o := defaultOverrides()
	o.Plugins.DynamicCursors.Enabled = true
	out := genLua(o, true)
	if !strings.Contains(out, `hl.plugin.load("`+so+`")`) {
		t.Errorf("expected user-path load %q:\n%s", so, out)
	}
	if strings.Contains(out, "/usr/lib/hyprland/plugins/dynamic-cursors.so") {
		t.Errorf("must not fall back to /usr/lib when the user .so exists:\n%s", out)
	}
}

// scrolling is core, not a plugin: its knobs emit under the core `scrolling`
// category only when that layout is selected, and never as an hl.plugin.load.
func TestGenPluginsScrollingCore(t *testing.T) {
	o := defaultOverrides()
	o.Appearance.Layout = "scrolling"
	o.Plugins.Hyprscrolling.ColumnWidth = 0.7
	o.Plugins.Hyprscrolling.FollowFocus = false
	out := genLua(o, true)
	if !strings.Contains(out, "hl.config({ scrolling = { column_width = 0.7, follow_focus = false } })") {
		t.Errorf("scrolling core config missing:\n%s", out)
	}
	if strings.Contains(out, "plugins/hyprscrolling.so") {
		t.Errorf("scrolling must not load a plugin:\n%s", out)
	}
	// same knobs but a non-scrolling layout: nothing emitted.
	o.Appearance.Layout = "dwindle"
	if strings.Contains(genLua(o, true), "scrolling = {") {
		t.Error("scrolling config emitted for a non-scrolling layout")
	}
	// scrolling layout at default knobs: no override written.
	d := defaultOverrides()
	d.Appearance.Layout = "scrolling"
	if strings.Contains(genPlugins(d), "scrolling = {") {
		t.Error("default scrolling knobs must emit no override")
	}
}

// plugin settings land on Save (reload), never through the live eval preview.
func TestPluginsNotPreviewed(t *testing.T) {
	o := defaultOverrides()
	o.Plugins.DynamicCursors.Enabled = true
	o.Plugins.Hyprbars.Enabled = true
	if strings.Contains(liveLua(o), "hl.plugin.load") {
		t.Error("plugins must not appear in the live preview (liveLua)")
	}
}

// a fully-enabled plugin set must still produce valid Lua.
func TestGenPluginsParse(t *testing.T) {
	o := defaultOverrides()
	o.Plugins.DynamicCursors.Enabled = true
	o.Plugins.Hyprbars.Enabled = true
	o.Plugins.Imgborders.Enabled = true
	o.Plugins.Imgborders.Image = "/tmp/b.png"
	o.Plugins.Hyprglass.Enabled = true
	o.Plugins.Hyprfocus.Enabled = true
	o.Appearance.Layout = "scrolling"
	o.Plugins.Hyprscrolling.ColumnWidth = 0.7
	lua := genLua(o, true)
	luac, err := exec.LookPath("luac")
	if err != nil {
		t.Skip("luac not available")
	}
	cmd := exec.Command(luac, "-p", "-")
	cmd.Stdin = strings.NewReader(lua)
	if out, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("genLua with all plugins does not parse: %v\n%s\n%s", err, out, lua)
	}
}

func TestLuaHex8(t *testing.T) {
	cases := map[string]string{
		"8899aa22": "8899aa22", "#8899AA22": "8899aa22", "0x8899aa22": "8899aa22",
		"bad": "8899aa22", "zzzzzzzz": "8899aa22", "": "8899aa22",
	}
	for in, want := range cases {
		if got := luaHex8(in); got != want {
			t.Errorf("luaHex8(%q) = %q, want %q", in, got, want)
		}
	}
}

// per-app appearance overrides emit one hl.window_rule of proven fields.
func TestGenAppOverride(t *testing.T) {
	a := AppOverride{
		Class: "kitty", Opacity: 0.9, Rounding: 8, BorderSize: 3,
		Blur: "off", Shadow: "off", Dim: "off", Anim: "off", Opaque: "on",
	}
	got := genAppOverride(0, a)
	for _, want := range []string{
		`class = "kitty"`, "opacity = 0.9", "rounding = 8", "border_size = 3",
		"no_blur = true", "no_shadow = true", "no_dim = true", "no_anim = true",
		"opaque = true", `name = "ryoku-app-1"`,
	} {
		if !strings.Contains(got, want) {
			t.Errorf("app override missing %q:\n%s", want, got)
		}
	}
}

// inherit fields (numeric -1, toggles "inherit") drop out entirely.
func TestGenAppOverrideInherit(t *testing.T) {
	a := AppOverride{
		Class: "kitty", Opacity: -1, Rounding: -1, BorderSize: -1,
		Blur: "inherit", Shadow: "inherit", Dim: "inherit", Anim: "inherit", Opaque: "inherit",
	}
	if got := genAppOverride(0, a); got != "" {
		t.Errorf("all-inherit override should emit nothing, got %q", got)
	}
	a.Opacity = 0.8
	got := genAppOverride(0, a)
	if !strings.Contains(got, "opacity = 0.8") {
		t.Errorf("set opacity missing:\n%s", got)
	}
	for _, no := range []string{"rounding", "border_size", "no_blur", "no_shadow", "no_dim", "no_anim", "opaque"} {
		if strings.Contains(got, no) {
			t.Errorf("inherit field %q leaked into output:\n%s", no, got)
		}
	}
}

// no class and no title -> no rule (a match-everything rule would reskin the
// whole desktop).
func TestGenAppOverrideNoMatch(t *testing.T) {
	if got := genAppOverride(0, AppOverride{Opacity: 0.5}); got != "" {
		t.Errorf("override with no match should emit nothing, got %q", got)
	}
}

// an app override rides through genLua as a window rule, so it overrides the
// global decoration on save.
func TestGenLuaAppOverride(t *testing.T) {
	o := defaultOverrides()
	o.AppOverrides = []AppOverride{{
		Class: "mpv", Opacity: 1, Rounding: 0, BorderSize: -1,
		Blur: "off", Shadow: "inherit", Dim: "inherit", Anim: "inherit", Opaque: "on",
	}}
	out := genLua(o, true)
	for _, want := range []string{`class = "mpv"`, "no_blur = true", "opaque = true"} {
		if !strings.Contains(out, want) {
			t.Errorf("app override not emitted through genLua (%q):\n%s", want, out)
		}
	}
}

// decoration extras (fullscreen / dim / blur / shadow) follow the same diff
// rule: only a changed leaf lands, and the shadow colour uses the rgb() helper.
func TestGenLuaDecorationExtras(t *testing.T) {
	o := defaultOverrides()
	o.Appearance.FullscreenOpacity = 0.9
	o.Appearance.DimSpecial = 0.5
	o.Appearance.DimAround = 0.6
	o.Appearance.DimModal = false
	o.Appearance.BorderPartOfWindow = false
	o.Appearance.BlurContrast = 1.2
	o.Appearance.BlurBrightness = 0.5
	o.Appearance.BlurSpecial = true
	o.Appearance.BlurPopups = true
	o.Appearance.BlurIgnoreOpacity = false
	o.Appearance.BlurNewOptimizations = false
	o.Appearance.BlurVibrancyDarkness = 0.5
	o.Appearance.ShadowSharp = true
	o.Appearance.ShadowScale = 0.8
	o.Appearance.ShadowColor = "#ffffff"
	out := genLua(o, true)
	for _, want := range []string{
		"fullscreen_opacity = 0.9", "dim_special = 0.5", "dim_around = 0.6",
		"dim_modal = false", "border_part_of_window = false",
		"contrast = 1.2", "brightness = 0.5", "special = true", "popups = true",
		"ignore_opacity = false", "new_optimizations = false", "vibrancy_darkness = 0.5",
		"sharp = true", "scale = 0.8", `color = "rgb(ffffff)"`,
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q:\n%s", want, out)
		}
	}
	// untouched leaves stay out of settings.lua.
	for _, not := range []string{"dim_strength", "noise"} {
		if strings.Contains(out, not) {
			t.Errorf("unchanged %q was emitted:\n%s", not, out)
		}
	}
}

// general extras (border grab, resize corner, workspace gaps) diff-guard the
// same way as the rest of the general block.
func TestGenLuaGeneralExtras(t *testing.T) {
	o := defaultOverrides()
	o.Appearance.ExtendBorderGrab = 20
	o.Appearance.HoverIconOnBorder = false
	o.Appearance.NoFocusFallback = true
	o.Appearance.ResizeCorner = 3
	o.Appearance.GapsWorkspaces = 10
	out := genLua(o, true)
	for _, want := range []string{
		"extend_border_grab_area = 20", "hover_icon_on_border = false",
		"no_focus_fallback = true", "resize_corner = 3", "gaps_workspaces = 10",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q:\n%s", want, out)
		}
	}
	if strings.Contains(out, "resize_on_border") {
		t.Errorf("unchanged resize_on_border was emitted:\n%s", out)
	}
}

// the dwindle layout knobs emit as their own diff-guarded `dwindle = {}` block,
// with the friendly force-split label mapped to Hyprland's integer.
func TestGenLuaDwindleSection(t *testing.T) {
	o := defaultOverrides()
	o.Dwindle.PreserveSplit = true
	o.Dwindle.SmartSplit = true
	o.Dwindle.SmartResizing = false
	o.Dwindle.DefaultSplitRatio = 1.3
	o.Dwindle.ForceSplit = "right/bottom"
	o.Dwindle.UseActiveForSplits = false
	out := genLua(o, true)
	if !strings.Contains(out, "dwindle = {") {
		t.Errorf("dwindle block missing:\n%s", out)
	}
	for _, want := range []string{
		"preserve_split = true", "smart_split = true", "smart_resizing = false",
		"default_split_ratio = 1.3", "force_split = 2", "use_active_for_splits = false",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q:\n%s", want, out)
		}
	}
	// master untouched -> no master block.
	if strings.Contains(out, "master = {") {
		t.Errorf("unchanged master block emitted:\n%s", out)
	}
	// force-split label maps by index.
	o.Dwindle.ForceSplit = "left/top"
	if !strings.Contains(genLua(o, true), "force_split = 1") {
		t.Errorf("force_split left/top should map to 1")
	}
	// all-default dwindle emits nothing.
	if strings.Contains(genLua(defaultOverrides(), true), "dwindle = {") {
		t.Errorf("default dwindle knobs must emit no block")
	}
}

// the master layout knobs emit as their own `master = {}` block; the enum knobs
// are Lua strings.
func TestGenLuaMasterSection(t *testing.T) {
	o := defaultOverrides()
	o.Master.Mfact = 0.6
	o.Master.NewStatus = "master"
	o.Master.NewOnTop = true
	o.Master.Orientation = "right"
	o.Master.SmartResizing = false
	out := genLua(o, true)
	if !strings.Contains(out, "master = {") {
		t.Errorf("master block missing:\n%s", out)
	}
	for _, want := range []string{
		"mfact = 0.6", `new_status = "master"`, "new_on_top = true",
		`orientation = "right"`, "smart_resizing = false",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q:\n%s", want, out)
		}
	}
	if strings.Contains(out, "dwindle = {") {
		t.Errorf("unchanged dwindle block emitted:\n%s", out)
	}
}

// the plugin option gaps (imgborders blur, hyprglass brightness / default_theme)
// pass through whenever their plugin is enabled.
func TestGenPluginsOptionExtras(t *testing.T) {
	o := defaultOverrides()
	o.Plugins.Hyprglass.Enabled = true
	o.Plugins.Hyprglass.Brightness = 1.5
	o.Plugins.Hyprglass.Theme = "light"
	o.Plugins.Imgborders.Enabled = true
	o.Plugins.Imgborders.Blur = true
	out := genLua(o, true)
	for _, want := range []string{
		"brightness = 1.5", `default_theme = "light"`, "blur = true",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q:\n%s", want, out)
		}
	}
}

// a saved store carrying the new top-level dwindle/master sections round-trips
// through parseOverrides into the emitted config (the hub's save path).
func TestParseOverridesDwindleMaster(t *testing.T) {
	o, err := parseOverrides(`{"dwindle":{"forceSplit":"left/top","smartResizing":false},"master":{"orientation":"center","mfact":0.7}}`)
	if err != nil {
		t.Fatalf("parseOverrides: %v", err)
	}
	out := genLua(o, true)
	for _, want := range []string{"force_split = 1", "smart_resizing = false", `orientation = "center"`, "mfact = 0.7"} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q:\n%s", want, out)
		}
	}
}
