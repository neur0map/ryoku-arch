package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

// overlayStore sets only allowlisted keys and never clobbers a key outside the
// allowlist (a shared rice must not overwrite a recipient's personal keys);
// extractStore is the inverse and leaks nothing outside the allowlist.
func TestOverlayAndExtractRespectAllowlist(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)
	p := shellStorePath()
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(p, []byte(`{"barStyle":"noctalia","weatherLocation":"Oslo","fontScale":1.3}`), 0o644); err != nil {
		t.Fatal(err)
	}

	if err := overlayStore(p, map[string]any{"barStyle": "caelestia", "weatherLocation": "X"}, riceShellLook); err != nil {
		t.Fatal(err)
	}
	got := readJSONMap(p)
	if got["barStyle"] != "caelestia" {
		t.Fatalf("barStyle = %v, want caelestia", got["barStyle"])
	}
	if got["weatherLocation"] != "Oslo" {
		t.Fatalf("non-allowlisted key clobbered: %v", got["weatherLocation"])
	}

	ex := extractStore(p, riceShellLook)
	if _, ok := ex["weatherLocation"]; ok {
		t.Fatal("extract leaked a non-allowlisted key")
	}
	if ex["fontScale"] == nil {
		t.Fatal("extract dropped an allowlisted key")
	}
}

// a rice round-trips through save/load, and listRices skips the reserved backup
// slots so they never appear as browsable rices.
func TestSaveLoadListRice(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)

	r := Rice{
		Schema: riceSchema, Slug: "demo", Name: "Demo", CreatedWith: "0.6.8",
		Color: RiceColor{Mode: "wallpaper"},
		Look:  map[string]map[string]any{"shell": {"barStyle": "delos"}},
	}
	if err := saveRice(r); err != nil {
		t.Fatal(err)
	}
	got, _, err := loadRice("demo")
	if err != nil {
		t.Fatal(err)
	}
	if got.Look["shell"]["barStyle"] != "delos" {
		t.Fatalf("round-trip lost look: %v", got.Look)
	}

	if err := os.MkdirAll(filepath.Join(ricesDir(), ".baseline"), 0o755); err != nil {
		t.Fatal(err)
	}
	ls := listRices()
	if len(ls) != 1 || ls[0].Slug != "demo" {
		t.Fatalf("listRices = %v, want [demo] (reserved slot skipped)", ls)
	}
}

// captureRice pulls only look keys into look, routes behavior keys to layers
// only when opted in, records the cursor by name, and reads the colour mode
// from the master. personal keys (weatherLocation) never travel.
func TestCaptureRice(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)
	if err := os.MkdirAll(filepath.Join(dir, "ryoku"), 0o755); err != nil {
		t.Fatal(err)
	}
	write := func(p, body string) {
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	write(hyprStorePath(), `{"appearance":{"rounding":10},"cursor":{"theme":"Bibata-Modern-Ice","size":24},"input":{"sensitivity":0.2}}`)
	write(shellStorePath(), `{"barStyle":"delos","weatherLocation":"Oslo"}`)
	write(launcherStorePath(), `{"heroStrength":0.5,"showWeather":true}`)
	write(themeStatePath(), `{"followWallpaper":true}`)

	r, err := captureRice("My Rice", nil)
	if err != nil {
		t.Fatal(err)
	}
	if r.Slug != "my-rice" {
		t.Fatalf("slug = %q, want my-rice", r.Slug)
	}
	if r.Look["hypr"]["appearance"] == nil {
		t.Fatal("appearance look missing")
	}
	if _, ok := r.Look["hypr"]["input"]; ok {
		t.Fatal("input leaked into look (it is a behavior layer)")
	}
	if r.Look["shell"]["barStyle"] != "delos" {
		t.Fatalf("shell barStyle = %v", r.Look["shell"]["barStyle"])
	}
	if _, ok := r.Look["shell"]["weatherLocation"]; ok {
		t.Fatal("personal key weatherLocation captured")
	}
	if r.Assets.Cursor != "Bibata-Modern-Ice" {
		t.Fatalf("cursor = %q", r.Assets.Cursor)
	}
	if r.Color.Mode != "wallpaper" {
		t.Fatalf("colour mode = %q, want wallpaper", r.Color.Mode)
	}
	if r.Layers != nil {
		t.Fatalf("no layers requested but got %v", r.Layers)
	}

	r2, err := captureRice("With Layer", []string{"input"})
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := r2.Layers["input"]; !ok {
		t.Fatalf("input layer not captured: %v", r2.Layers)
	}
}

// applyRice merges only allowlisted look keys onto the live stores (a personal
// key survives), flips the colour master for a fixed rice and writes its
// palette, and reloads. restoreRice(".baseline") then reverts every store to
// the pristine pre-apply snapshot.
func TestApplyMergesAndRestoreReverts(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)
	t.Setenv("XDG_CACHE_HOME", filepath.Join(dir, "cache"))
	t.Setenv("HOME", dir)
	if err := os.MkdirAll(filepath.Join(dir, "ryoku"), 0o755); err != nil {
		t.Fatal(err)
	}

	var calls []string
	origRun, origReload := riceRun, riceReload
	riceRun = func(name string, args ...string) error { calls = append(calls, name); return nil }
	riceReload = func() { calls = append(calls, "reload") }
	t.Cleanup(func() { riceRun, riceReload = origRun, origReload })

	w := func(p, body string) {
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	w(hyprStorePath(), `{"appearance":{"rounding":2},"cursor":{"theme":"Bibata-Modern-Ice","size":24}}`)
	w(shellStorePath(), `{"barStyle":"noctalia","weatherLocation":"Oslo"}`)
	w(launcherStorePath(), `{"heroStrength":0.6}`)
	w(themeStatePath(), `{"followWallpaper":true}`)

	if err := os.MkdirAll(filepath.Join(ricesDir(), "cool"), 0o755); err != nil {
		t.Fatal(err)
	}
	w(filepath.Join(ricesDir(), "cool", "palette.json"), `{"background":"#101010","color4":"#ff8800","foreground":"#eeeeee"}`)
	w(ricePath("cool"), `{"schema":1,"slug":"cool","name":"Cool","color":{"mode":"fixed","palette":"palette.json"},"look":{"hypr":{"appearance":{"rounding":18}},"shell":{"barStyle":"caelestia"},"launcher":{}}}`)

	if err := applyRice("cool", nil); err != nil {
		t.Fatal(err)
	}
	shell := readJSONMap(shellStorePath())
	if shell["barStyle"] != "caelestia" {
		t.Fatalf("apply did not set barStyle: %v", shell["barStyle"])
	}
	if shell["weatherLocation"] != "Oslo" {
		t.Fatal("apply clobbered a personal key")
	}
	ap := readJSONMap(hyprStorePath())["appearance"].(map[string]any)
	if ap["rounding"].(float64) != 18 {
		t.Fatalf("apply rounding = %v, want 18", ap["rounding"])
	}
	if loadThemeState().FollowWallpaper {
		t.Fatal("a fixed rice must turn off followWallpaper")
	}
	if !isFile(filepath.Join(dir, "cache", "wallust", "colors.json")) {
		t.Fatal("fixed palette not written to the wallust cache")
	}
	reloaded := false
	for _, c := range calls {
		if c == "reload" {
			reloaded = true
		}
	}
	if !reloaded {
		t.Fatalf("apply did not reload; calls = %v", calls)
	}

	if err := restoreRice(".baseline"); err != nil {
		t.Fatal(err)
	}
	shell2 := readJSONMap(shellStorePath())
	if shell2["barStyle"] != "noctalia" {
		t.Fatalf("restore did not revert barStyle: %v", shell2["barStyle"])
	}
	ap2 := readJSONMap(hyprStorePath())["appearance"].(map[string]any)
	if ap2["rounding"].(float64) != 2 {
		t.Fatalf("restore rounding = %v, want 2", ap2["rounding"])
	}
	if !loadThemeState().FollowWallpaper {
		t.Fatal("restore did not revert followWallpaper")
	}
}

// riceTouches flags which config stores a rice provides and includes the fixed
// palette outputs and bundled assets; exportRice lays the manifest, a per-store
// configs breakout, and a README into a plain folder.
func TestRiceTouchesAndExport(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)

	r := Rice{
		Schema: riceSchema, Slug: "demo", Name: "Demo", Author: "Ryoku Team",
		CreatedWith: "0.6.8",
		Color:       RiceColor{Mode: "fixed", Palette: "palette.json"},
		Assets:      RiceAssets{Wallpaper: "wall.png"},
		Look:        map[string]map[string]any{"hypr": {"rounding": 3.0}, "shell": {"barStyle": "stele"}},
	}
	rdir := filepath.Join(ricesDir(), "demo")
	if err := os.MkdirAll(rdir, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := saveRice(r); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(rdir, "palette.json"), []byte(`{"color0":"#000"}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(rdir, "wall.png"), []byte("img"), 0o644); err != nil {
		t.Fatal(err)
	}

	touches := riceTouches(r, rdir)
	find := func(sub string) *riceTouch {
		for i := range touches {
			if strings.Contains(touches[i].Path, sub) || strings.Contains(touches[i].Label, sub) {
				return &touches[i]
			}
		}
		return nil
	}
	if h := find("hypr.json"); h == nil || !h.Provided {
		t.Fatalf("hypr.json not reported as provided: %+v", h)
	}
	if l := find("launcher.json"); l == nil || l.Provided {
		t.Fatalf("launcher.json should be present but not provided: %+v", l)
	}
	if find("wallust") == nil {
		t.Fatal("fixed rice should touch the wallust cache")
	}
	if find("Desktop wallpaper") == nil {
		t.Fatal("bundled wallpaper not reported")
	}

	dest := t.TempDir()
	out, err := exportRice("demo", dest)
	if err != nil {
		t.Fatal(err)
	}
	for _, f := range []string{"rice.json", "palette.json", "wall.png", "README.txt", filepath.Join("configs", "hypr.json"), filepath.Join("configs", "shell.json")} {
		if !isFile(filepath.Join(out, f)) {
			t.Fatalf("export missing %s", f)
		}
	}
}

// captureRice with "all" pulls every non-empty behavior layer (keybinds
// included) while skipping empty sections, and riceTouches then lists them so
// the setup is fully installable and removable.
func TestCaptureAllLayersAndTouches(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)
	if err := os.MkdirAll(filepath.Join(dir, "ryoku"), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(hyprStorePath(), []byte(`{"appearance":{"rounding":0},"keybinds":[{"keys":"SUPER + T","action":"exec","value":"kitty"}],"windowRules":[{"class":"Spotify","action":"float"}],"input":[]}`), 0o644); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(themeStatePath(), []byte(`{"followWallpaper":true}`), 0o644); err != nil {
		t.Fatal(err)
	}

	r, err := captureRice("Full", []string{"all"})
	if err != nil {
		t.Fatal(err)
	}
	if _, ok := r.Layers["keybinds"]; !ok {
		t.Fatalf("keybinds not captured by full capture: %v", r.Layers)
	}
	if _, ok := r.Layers["windowRules"]; !ok {
		t.Fatalf("windowRules not captured by full capture: %v", r.Layers)
	}
	if _, ok := r.Layers["input"]; ok {
		t.Fatal("empty input layer should be skipped, not captured")
	}

	touches := riceTouches(r, filepath.Join(ricesDir(), r.Slug))
	hasKeybinds := false
	for _, tc := range touches {
		if tc.Label == "Keybinds" {
			hasKeybinds = true
		}
	}
	if !hasKeybinds {
		t.Fatal("touches list should include the captured Keybinds config")
	}
}

// a rice carrying a square shell shape and a keybinds layer installs both (the
// frame, island and chrome go square alongside the windows, and the keybind
// lands), and restore removes them, so every config round-trips end to end.
func TestSquareShellAndKeybindRoundTrip(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)
	t.Setenv("XDG_CACHE_HOME", filepath.Join(dir, "cache"))
	t.Setenv("HOME", dir)
	if err := os.MkdirAll(filepath.Join(dir, "ryoku"), 0o755); err != nil {
		t.Fatal(err)
	}
	origRun, origReload := riceRun, riceReload
	riceRun = func(name string, args ...string) error { return nil }
	riceReload = func() {}
	t.Cleanup(func() { riceRun, riceReload = origRun, origReload })

	w := func(p, body string) {
		if err := os.WriteFile(p, []byte(body), 0o644); err != nil {
			t.Fatal(err)
		}
	}
	w(hyprStorePath(), `{"appearance":{"rounding":12},"keybinds":[]}`)
	w(shellStorePath(), `{"barStyle":"noctalia","frameRadius":9,"islandRadius":17,"roundness":10,"osdRadius":12}`)
	w(launcherStorePath(), `{}`)
	w(themeStatePath(), `{"followWallpaper":true}`)

	if err := os.MkdirAll(filepath.Join(ricesDir(), "sq"), 0o755); err != nil {
		t.Fatal(err)
	}
	w(ricePath("sq"), `{"schema":1,"slug":"sq","name":"Square","color":{"mode":"wallpaper"},"look":{"hypr":{"appearance":{"rounding":0}},"shell":{"frameRadius":0,"islandRadius":0,"roundness":0,"osdRadius":0},"launcher":{}},"layers":{"keybinds":[{"keys":"SUPER + T","action":"exec","value":"kitty"}]}}`)

	if err := applyRice("sq", []string{"keybinds"}); err != nil {
		t.Fatal(err)
	}
	shell := readJSONMap(shellStorePath())
	for _, k := range []string{"frameRadius", "islandRadius", "roundness", "osdRadius"} {
		if v, ok := shell[k].(float64); !ok || v != 0 {
			t.Fatalf("square rice did not set shell %s to 0: %v", k, shell[k])
		}
	}
	ap := readJSONMap(hyprStorePath())["appearance"].(map[string]any)
	if ap["rounding"].(float64) != 0 {
		t.Fatalf("square rice did not set window rounding to 0: %v", ap["rounding"])
	}
	if kb, _ := readJSONMap(hyprStorePath())["keybinds"].([]any); len(kb) != 1 {
		t.Fatalf("keybinds layer not installed: %v", readJSONMap(hyprStorePath())["keybinds"])
	}

	if err := restoreRice(".baseline"); err != nil {
		t.Fatal(err)
	}
	shell2 := readJSONMap(shellStorePath())
	if shell2["frameRadius"].(float64) != 9 || shell2["islandRadius"].(float64) != 17 {
		t.Fatalf("restore did not revert the frame/island shape: %v", shell2)
	}
	if kb2, _ := readJSONMap(hyprStorePath())["keybinds"].([]any); len(kb2) != 0 {
		t.Fatalf("restore did not remove the installed keybind: %v", readJSONMap(hyprStorePath())["keybinds"])
	}
}
