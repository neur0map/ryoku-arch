package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
)

// rice = a named, versioned look document for the whole desktop. it captures a
// curated view of the four user-owned stores under ~/.config/ryoku (hypr.json,
// shell.json, theme.json, launcher.json) plus assets (wallpaper, launcher hero,
// cursor, fonts), so a whole desktop look can be saved, applied, shared, and
// reverted in one click. see docs/superpowers/specs (local).
//
// capture and apply are uniform per-store map overlays gated by a per-store key
// allowlist: a capture pulls only look-defining keys, an apply sets only those
// keys and leaves everything else the recipient has alone (their keybinds,
// input, machine state never move unless a behavior layer is opted into).

const riceSchema = 1

type RiceColor struct {
	Mode    string `json:"mode"`              // "wallpaper" | "fixed"
	Palette string `json:"palette,omitempty"` // relative file, when Mode == "fixed"
}

type RiceAssets struct {
	Wallpaper string   `json:"wallpaper,omitempty"`
	Hero      string   `json:"hero,omitempty"`
	Cursor    string   `json:"cursor,omitempty"`
	Fonts     []string `json:"fonts,omitempty"`
}

type Rice struct {
	Schema      int                        `json:"schema"`
	Slug        string                     `json:"slug"`
	Name        string                     `json:"name"`
	Author      string                     `json:"author,omitempty"`
	Blurb       string                     `json:"blurb,omitempty"`
	Tags        []string                   `json:"tags,omitempty"`
	CreatedWith string                     `json:"createdWith,omitempty"`
	Color       RiceColor                  `json:"color"`
	Assets      RiceAssets                 `json:"assets"`
	Look        map[string]map[string]any  `json:"look"`
	Layers      map[string]json.RawMessage `json:"layers,omitempty"`
}

func ryokuConfigDir() string {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".config")
	}
	return filepath.Join(base, "ryoku")
}

func ricesDir() string          { return filepath.Join(ryokuConfigDir(), "rices") }
func shellStorePath() string    { return filepath.Join(ryokuConfigDir(), "shell.json") }
func launcherStorePath() string { return filepath.Join(ryokuConfigDir(), "launcher.json") }
func ricePath(slug string) string {
	return filepath.Join(ricesDir(), slug, "rice.json")
}

// the four stores hold arbitrary JSON; a rice touches only its per-store
// allowlist. hypr.json splits cleanly at the top level: the look sections are
// always captured, the behavior sections are opt-in layers. shell/launcher are
// flat key sets (personal keys like weather / greeting are deliberately absent
// so a shared rice never overwrites them).
var riceHyprLook = []string{"appearance", "cursor", "anim", "plugins"}
var riceHyprLayers = []string{"input", "windowRules", "layerRules", "appOverrides", "keybinds", "autostart", "env"}
var riceShellLook = []string{
	"frameRadius", "frameBorder", "frameSmoothing", "frameOpacity", "shadowStrength", "shadowSize",
	"surfaceColor", "osdRadius", "osdOpacity",
	"barEnabled", "barPosition", "barStyle", "barHeight", "barShowTitle", "barShowMedia", "barShowStatus", "barOccupiedWorkspaces",
	"islandEdge", "islandAlong", "islandHidden", "islandModules", "islandRadius",
	"islandStyle", "islandWidth", "islandHeight", "islandRestCorner", "islandOpenCorner", "islandGap", "islandSmoothing", "islandOpacity", "islandAutohide",
	"sidebarLeftEnabled", "sidebarRightEnabled", "sidebarLeftPanes", "sidebarRightPanes", "sidebarClickless", "sidebarWidth", "sidebarCornerSize",
	"roundness", "fontFamily", "fontScale",
}
var riceLauncherLook = []string{"heroImage", "heroStrength", "heroPosX", "heroPosY"}

// readJSONMap reads a store file into a generic map; a missing or torn file
// reads as an empty map so an overlay still lands on a fresh key set.
func readJSONMap(path string) map[string]any {
	m := map[string]any{}
	if b, err := os.ReadFile(path); err == nil {
		_ = json.Unmarshal(b, &m)
	}
	return m
}

// pick copies the allowlisted keys present in src into a fresh map.
func pick(src map[string]any, allow []string) map[string]any {
	out := map[string]any{}
	for _, k := range allow {
		if v, ok := src[k]; ok {
			out[k] = v
		}
	}
	return out
}

// overlayStore sets the allowlisted keys from src into the store file, leaves
// every other key untouched, and writes atomically. unknown keys in src are
// ignored, so a rice built on an older schema can never inject a retired key.
func overlayStore(path string, src map[string]any, allow []string) error {
	cur := readJSONMap(path)
	for _, k := range allow {
		if v, ok := src[k]; ok {
			cur[k] = v
		}
	}
	return atomicWrite(path, mustJSON(cur), 0o644)
}

func extractStore(path string, allow []string) map[string]any {
	return pick(readJSONMap(path), allow)
}

func loadRice(slug string) (Rice, string, error) {
	var r Rice
	dir := filepath.Join(ricesDir(), slug)
	b, err := os.ReadFile(filepath.Join(dir, "rice.json"))
	if err != nil {
		return r, dir, err
	}
	err = json.Unmarshal(b, &r)
	return r, dir, err
}

func saveRice(r Rice) error {
	return atomicWrite(ricePath(r.Slug), mustJSON(r), 0o644)
}

// listRices returns every user rice, sorted by slug for a stable UI. the
// reserved backup slots (.baseline / .previous) and any dotdir are skipped.
func listRices() []Rice {
	entries, _ := os.ReadDir(ricesDir())
	out := []Rice{}
	for _, e := range entries {
		if !e.IsDir() || strings.HasPrefix(e.Name(), ".") {
			continue
		}
		if r, _, err := loadRice(e.Name()); err == nil {
			out = append(out, r)
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Slug < out[j].Slug })
	return out
}

func slugify(s string) string {
	var b strings.Builder
	prevDash := false
	for _, r := range strings.ToLower(strings.TrimSpace(s)) {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
			prevDash = false
		} else if b.Len() > 0 && !prevDash {
			b.WriteByte('-')
			prevDash = true
		}
	}
	return strings.Trim(b.String(), "-")
}

func currentUser() string {
	if u, err := user.Current(); err == nil {
		return u.Username
	}
	return ""
}

// ryokuVersion is the running Ryoku base version (the createdWith tag). Best
// effort: an empty string when the ryoku CLI is not on PATH (e.g. tests).
func ryokuVersion() string {
	out, err := exec.Command("ryoku", "version").Output()
	if err != nil {
		return ""
	}
	return strings.TrimPrefix(strings.TrimSpace(string(out)), "v")
}

func allowed(k string, allow []string) bool {
	for _, a := range allow {
		if a == k {
			return true
		}
	}
	return false
}

func isFile(p string) bool {
	if p == "" {
		return false
	}
	fi, err := os.Stat(p)
	return err == nil && !fi.IsDir()
}

func copyFile(src, dst string) error {
	b, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return atomicWrite(dst, b, 0o644)
}

func stateHome() string {
	if b := os.Getenv("XDG_STATE_HOME"); b != "" {
		return b
	}
	return filepath.Join(os.Getenv("HOME"), ".local", "state")
}

// currentWallpaper reads the path the shell recorded for the live wallpaper.
func currentWallpaper() string {
	b, err := os.ReadFile(filepath.Join(stateHome(), "ryoku-wallpaper"))
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func launcherHero() string {
	if h, ok := readJSONMap(launcherStorePath())["heroImage"].(string); ok {
		return h
	}
	return ""
}

// captureRice snapshots the live look (plus the requested behavior layers) into
// a new user rice, bundling the wallpaper, launcher hero, and (for a locked
// palette) the wallust colours. cursor and fonts travel by name.
func captureRice(name string, layers []string) (Rice, error) {
	slug := slugify(name)
	if slug == "" {
		return Rice{}, fmt.Errorf("a rice needs a name")
	}
	hy := readJSONMap(hyprStorePath())
	r := Rice{
		Schema:      riceSchema,
		Slug:        slug,
		Name:        strings.TrimSpace(name),
		Author:      currentUser(),
		CreatedWith: ryokuVersion(),
		Look: map[string]map[string]any{
			"hypr":     pick(hy, riceHyprLook),
			"shell":    extractStore(shellStorePath(), riceShellLook),
			"launcher": extractStore(launcherStorePath(), riceLauncherLook),
		},
	}
	if len(layers) == 1 && layers[0] == "all" {
		layers = riceHyprLayers
	}
	if len(layers) > 0 {
		r.Layers = map[string]json.RawMessage{}
		for _, l := range layers {
			if !allowed(l, riceHyprLayers) {
				continue
			}
			v, ok := hy[l]
			if !ok || isEmptyLayer(v) {
				continue
			}
			if b, err := json.Marshal(v); err == nil {
				r.Layers[l] = b
			}
		}
		if len(r.Layers) == 0 {
			r.Layers = nil
		}
	}
	if cur, ok := hy["cursor"].(map[string]any); ok {
		if t, ok := cur["theme"].(string); ok {
			r.Assets.Cursor = t
		}
	}
	if loadThemeState().FollowWallpaper {
		r.Color = RiceColor{Mode: "wallpaper"}
	} else {
		r.Color = RiceColor{Mode: "fixed", Palette: "palette.json"}
	}
	if err := saveRice(r); err != nil {
		return r, err
	}
	dir := filepath.Join(ricesDir(), slug)
	if wp := currentWallpaper(); isFile(wp) {
		asset := "wall" + filepath.Ext(wp)
		if copyFile(wp, filepath.Join(dir, asset)) == nil {
			r.Assets.Wallpaper = asset
		}
	}
	if hero := launcherHero(); isFile(hero) {
		asset := "hero" + filepath.Ext(hero)
		if copyFile(hero, filepath.Join(dir, asset)) == nil {
			r.Assets.Hero = asset
		}
	}
	if r.Color.Mode == "fixed" {
		if copyFile(filepath.Join(wallustCacheDir(), "colors.json"), filepath.Join(dir, "palette.json")) != nil {
			r.Color = RiceColor{Mode: "wallpaper"} // no cached palette: follow the wallpaper instead
		}
	}
	return r, saveRice(r)
}

// isEmptyLayer treats a nil, empty array, or empty object as no config, so a
// full capture never bloats a rice with sections the user never set.
func isEmptyLayer(v any) bool {
	switch t := v.(type) {
	case nil:
		return true
	case []any:
		return len(t) == 0
	case map[string]any:
		return len(t) == 0
	}
	return false
}

// riceRun / riceReload wrap the external effects (wallpaper daemon, cursor,
// compositor reload) so tests can observe an apply without a live session.
var riceRun = func(name string, args ...string) error { return exec.Command(name, args...).Run() }
var riceReload = func() { hyprReload() }

func wallpaperDir() string { return filepath.Join(os.Getenv("HOME"), "Pictures", "Wallpapers") }

func setLauncherHero(abs string) {
	m := readJSONMap(launcherStorePath())
	m["heroImage"] = abs
	_ = atomicWrite(launcherStorePath(), mustJSON(m), 0o644)
}

func readPalette(path string) map[string]string {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var p map[string]string
	if json.Unmarshal(b, &p) != nil {
		return nil
	}
	return p
}

// the reserved backup slots snapshot the four stores verbatim, so a restore is
// a byte-for-byte revert (not an allowlisted merge). that is what makes
// "restore my original setup" trustworthy.
var backupStores = []string{"hypr.json", "shell.json", "launcher.json", "theme.json"}

func snapshotStores(slot string) error {
	dir := filepath.Join(ricesDir(), slot)
	for _, f := range backupStores {
		src := filepath.Join(ryokuConfigDir(), f)
		if !isFile(src) {
			continue
		}
		if err := copyFile(src, filepath.Join(dir, f)); err != nil {
			return err
		}
	}
	if wp := currentWallpaper(); wp != "" {
		_ = atomicWrite(filepath.Join(dir, "wallpaper.path"), []byte(wp), 0o644)
	}
	return nil
}

// ensureBaseline snapshots the pristine pre-rice setup exactly once; it is never
// overwritten, so the user can always return to how the machine shipped/was.
func ensureBaseline() {
	if !isFile(filepath.Join(ricesDir(), ".baseline", "hypr.json")) {
		_ = snapshotStores(".baseline")
	}
}

// restoreRice reverts to a reserved slot (.baseline = pristine pre-rice,
// .previous = the state before the last apply), then re-sets the wallpaper and
// reloads so the live session matches the reverted files.
func restoreRice(slot string) error {
	dir := filepath.Join(ricesDir(), slot)
	restored := false
	for _, f := range backupStores {
		src := filepath.Join(dir, f)
		if !isFile(src) {
			continue
		}
		if err := copyFile(src, filepath.Join(ryokuConfigDir(), f)); err != nil {
			return err
		}
		restored = true
	}
	if !restored {
		return fmt.Errorf("no backup to restore at %q", slot)
	}
	if b, err := os.ReadFile(filepath.Join(dir, "wallpaper.path")); err == nil && isFile(strings.TrimSpace(string(b))) {
		_ = riceRun("ryoku-shell", "wallpaper", "set", strings.TrimSpace(string(b)))
	} else {
		_ = riceRun("ryoku-shell", "wallpaper", "repaint")
	}
	_ = writeGeneratedLua(loadOverrides())
	riceReload()
	return nil
}

// applyRice merges a rice onto the live stores and reloads. it first snapshots
// the current setup into .previous (and .baseline once) so revert is one click.
func applyRice(slug string, layers []string) error {
	r, dir, err := loadRice(slug)
	if err != nil {
		return err
	}
	_ = snapshotStores(".previous")
	ensureBaseline()

	overlayStore(hyprStorePath(), r.Look["hypr"], riceHyprLook)
	if len(layers) > 0 && r.Layers != nil {
		hy := readJSONMap(hyprStorePath())
		changed := false
		for _, l := range layers {
			if raw, ok := r.Layers[l]; ok {
				var v any
				if json.Unmarshal(raw, &v) == nil {
					hy[l] = v
					changed = true
				}
			}
		}
		if changed {
			_ = atomicWrite(hyprStorePath(), mustJSON(hy), 0o644)
		}
	}
	overlayStore(shellStorePath(), r.Look["shell"], riceShellLook)
	overlayStore(launcherStorePath(), r.Look["launcher"], riceLauncherLook)

	st := loadThemeState()
	if r.Color.Mode == "fixed" {
		st.FollowWallpaper = false
		st.Scheme = ""
		saveThemeState(st)
		if pal := readPalette(filepath.Join(dir, r.Color.Palette)); pal != nil {
			writePalette(pal)
		}
		_ = riceRun("ryoku-shell", "wallpaper", "repaint")
	} else {
		st.FollowWallpaper = true
		saveThemeState(st)
	}

	if r.Assets.Wallpaper != "" {
		dst := filepath.Join(wallpaperDir(), r.Slug+filepath.Ext(r.Assets.Wallpaper))
		if copyFile(filepath.Join(dir, r.Assets.Wallpaper), dst) == nil {
			_ = riceRun("ryoku-shell", "wallpaper", "set", dst)
		}
	}
	if r.Assets.Hero != "" {
		dst := filepath.Join(ryokuConfigDir(), "rice-hero"+filepath.Ext(r.Assets.Hero))
		if copyFile(filepath.Join(dir, r.Assets.Hero), dst) == nil {
			setLauncherHero(dst)
		}
	}
	if r.Assets.Cursor != "" {
		o := loadOverrides()
		o.Cursor.Theme = r.Assets.Cursor
		_ = saveOverrides(o)
		_ = riceRun("hyprctl", "setcursor", o.Cursor.Theme, fmt.Sprintf("%d", o.Cursor.Size))
	}

	_ = writeGeneratedLua(loadOverrides())
	riceReload()
	return nil
}

// --- active rice + compatibility -------------------------------------------

func activePath() string { return filepath.Join(ricesDir(), ".active") }

func activeRice() string {
	b, _ := os.ReadFile(activePath())
	return strings.TrimSpace(string(b))
}

func setActiveRice(slug string) { _ = atomicWrite(activePath(), []byte(slug), 0o644) }

// majorMinor pulls the (major, minor) from a version like "0.6.8-beta.17".
func majorMinor(v string) (int, int, bool) {
	base := v
	if i := strings.IndexByte(base, '-'); i >= 0 {
		base = base[:i]
	}
	parts := strings.Split(base, ".")
	if len(parts) < 2 {
		return 0, 0, false
	}
	maj, err1 := strconv.Atoi(parts[0])
	min, err2 := strconv.Atoi(parts[1])
	if err1 != nil || err2 != nil {
		return 0, 0, false
	}
	return maj, min, true
}

// riceCompat marks a rice against the running Ryoku: ok (same major.minor),
// older (built for an earlier Ryoku, may need migration), newer (built for a
// later one), or unknown.
func riceCompat(createdWith string) string {
	cM, cm, ok1 := majorMinor(ryokuVersion())
	rM, rm, ok2 := majorMinor(createdWith)
	if !ok1 || !ok2 {
		return "unknown"
	}
	switch {
	case rM == cM && rm == cm:
		return "ok"
	case rM < cM || (rM == cM && rm < cm):
		return "older"
	default:
		return "newer"
	}
}

// --- the UI-facing list ----------------------------------------------------

// riceListEntry is a rice plus the fields the Rices tab needs: compatibility
// against the running Ryoku, whether it is the applied rice, and a preview URL.
type riceListEntry struct {
	Rice
	Compat  string `json:"compat"`
	Active  bool   `json:"active"`
	Preview string `json:"preview,omitempty"`
}

func listRiceEntries() []riceListEntry {
	active := activeRice()
	out := []riceListEntry{}
	for _, r := range listRices() {
		e := riceListEntry{Rice: r, Compat: riceCompat(r.CreatedWith), Active: r.Slug == active}
		dir := filepath.Join(ricesDir(), r.Slug)
		if p := filepath.Join(dir, "preview.png"); isFile(p) {
			e.Preview = "file://" + p
		} else if r.Assets.Wallpaper != "" && isFile(filepath.Join(dir, r.Assets.Wallpaper)) {
			e.Preview = "file://" + filepath.Join(dir, r.Assets.Wallpaper)
		}
		out = append(out, e)
	}
	return out
}

// setRiceWallpaper bundles a chosen image into a user rice as its wallpaper, so
// it applies on the desktop and doubles as the rice's preview.
func setRiceWallpaper(slug, src string) error {
	if !validRiceSlug(slug) {
		return fmt.Errorf("bad rice slug %q", slug)
	}
	if !isFile(src) {
		return fmt.Errorf("no such image: %s", src)
	}
	r, dir, err := loadRice(slug)
	if err != nil {
		return err
	}
	asset := "wall" + filepath.Ext(src)
	if err := copyFile(src, filepath.Join(dir, asset)); err != nil {
		return err
	}
	r.Assets.Wallpaper = asset
	return saveRice(r)
}

// --- files / export --------------------------------------------------------

// riceTouch is one path applying a rice writes, or one asset it bundles.
type riceTouch struct {
	Path     string `json:"path"`
	Kind     string `json:"kind"` // config | output | asset
	Icon     string `json:"icon"`
	Label    string `json:"label"`
	Provided bool   `json:"provided"`
}

// homeRel shortens a path under $HOME to a ~ path for display.
func homeRel(p string) string {
	if h := os.Getenv("HOME"); h != "" && strings.HasPrefix(p, h) {
		return "~" + p[len(h):]
	}
	return p
}

// riceTouches reports every path applying the rice writes (its config stores
// and the outputs regenerated from them) plus the assets it carries, each
// flagged by whether the rice actually provides it.
func riceTouches(r Rice, dir string) []riceTouch {
	cfg := ryokuConfigDir()
	touches := []riceTouch{
		{homeRel(filepath.Join(cfg, "hypr.json")), "config", "window", "Windows: decoration and motion", len(r.Look["hypr"]) > 0},
		{homeRel(filepath.Join(cfg, "shell.json")), "config", "widgets", "Shell: bar skin and modules", len(r.Look["shell"]) > 0},
		{homeRel(filepath.Join(cfg, "theme.json")), "config", "palette", "Colours: palette master", r.Color.Mode != "" || len(r.Look["theme"]) > 0},
		{homeRel(filepath.Join(cfg, "launcher.json")), "config", "rocket", "Launcher: hero image", len(r.Look["launcher"]) > 0 || r.Assets.Hero != ""},
		{homeRel(filepath.Join(hyprConfigDir(), "settings.lua")), "output", "refresh", "Hyprland settings (regenerated)", true},
	}
	if r.Color.Mode == "fixed" {
		touches = append(touches,
			riceTouch{homeRel(filepath.Join(wallustCacheDir(), "colors.json")), "output", "refresh", "Colour palette (wallust cache)", true},
			riceTouch{homeRel(kittyThemePath()), "output", "terminal", "kitty colours", true},
		)
	}
	if r.Assets.Wallpaper != "" {
		touches = append(touches, riceTouch{homeRel(filepath.Join(dir, r.Assets.Wallpaper)), "asset", "wallpaper", "Desktop wallpaper", true})
	}
	if r.Assets.Hero != "" {
		touches = append(touches, riceTouch{homeRel(filepath.Join(dir, r.Assets.Hero)), "asset", "image", "Launcher hero", true})
	}
	if r.Color.Palette != "" {
		touches = append(touches, riceTouch{homeRel(filepath.Join(dir, r.Color.Palette)), "asset", "palette", "Fixed 16-colour palette", isFile(filepath.Join(dir, r.Color.Palette))})
	}
	if r.Assets.Cursor != "" {
		touches = append(touches, riceTouch{r.Assets.Cursor, "asset", "mouse", "Cursor theme", true})
	}
	layerRows := []struct {
		key, icon, label string
	}{
		{"keybinds", "keyboard", "Keybinds"},
		{"input", "mouse", "Input (pointer, keyboard)"},
		{"windowRules", "window", "Window rules"},
		{"layerRules", "widgets", "Layer rules"},
		{"appOverrides", "window", "Per-app overrides"},
		{"autostart", "rocket", "Autostart"},
		{"env", "variable", "Environment"},
	}
	for _, lr := range layerRows {
		if _, ok := r.Layers[lr.key]; ok {
			touches = append(touches, riceTouch{homeRel(filepath.Join(cfg, "hypr.json")), "config", lr.icon, lr.label, true})
		}
	}
	return touches
}

// riceFiles prints what a rice touches plus its manifest, for the Hub's
// "what it touches" list and config viewer.
func riceFiles(slug string) error {
	r, dir, err := loadRice(slug)
	if err != nil {
		return err
	}
	return printJSON(struct {
		Touches []riceTouch `json:"touches"`
		Config  string      `json:"config"`
	}{
		Touches: riceTouches(r, dir),
		Config:  string(mustJSON(r)),
	})
}

// exportRice extracts a rice into dest/<slug>/: its manifest and assets, a
// readable configs/ breakout of the per-store look, and a short README, so the
// whole setup travels as a plain, inspectable folder.
func exportRice(slug, dest string) (string, error) {
	if !validRiceSlug(slug) {
		return "", fmt.Errorf("bad rice slug %q", slug)
	}
	r, dir, err := loadRice(slug)
	if err != nil {
		return "", err
	}
	if fi, err := os.Stat(dest); err != nil || !fi.IsDir() {
		return "", fmt.Errorf("not a folder: %s", dest)
	}
	out := filepath.Join(dest, slug)
	if err := os.MkdirAll(out, 0o755); err != nil {
		return "", err
	}
	ents, err := os.ReadDir(dir)
	if err != nil {
		return "", err
	}
	for _, e := range ents {
		if e.IsDir() {
			continue
		}
		if err := copyFile(filepath.Join(dir, e.Name()), filepath.Join(out, e.Name())); err != nil {
			return "", err
		}
	}
	cfgDir := filepath.Join(out, "configs")
	if err := os.MkdirAll(cfgDir, 0o755); err != nil {
		return "", err
	}
	for store, vals := range r.Look {
		if len(vals) == 0 {
			continue
		}
		if err := atomicWrite(filepath.Join(cfgDir, store+".json"), mustJSON(vals), 0o644); err != nil {
			return "", err
		}
	}
	if err := atomicWrite(filepath.Join(out, "README.txt"), []byte(exportReadme(r)), 0o644); err != nil {
		return "", err
	}
	return out, nil
}

func exportReadme(r Rice) string {
	name := r.Name
	if name == "" {
		name = r.Slug
	}
	var b strings.Builder
	fmt.Fprintf(&b, "Ryoku rice: %s\n", name)
	if r.Author != "" {
		fmt.Fprintf(&b, "By %s\n", r.Author)
	}
	if r.Blurb != "" {
		fmt.Fprintf(&b, "\n%s\n", r.Blurb)
	}
	b.WriteString("\nContents\n")
	b.WriteString("  rice.json    the manifest: the look values and asset names\n")
	b.WriteString("  configs/     the same look broken out per config file, to read\n")
	if r.Color.Palette != "" {
		b.WriteString("  palette.json the fixed 16-colour palette\n")
	}
	if r.Assets.Wallpaper != "" {
		fmt.Fprintf(&b, "  %s   the desktop wallpaper\n", r.Assets.Wallpaper)
	}
	if r.Assets.Hero != "" {
		fmt.Fprintf(&b, "  %s   the launcher hero image\n", r.Assets.Hero)
	}
	fmt.Fprintf(&b, "\nDrop this folder into ~/.config/ryoku/rices/ and apply it from\nRyoku Settings > Appearance > Rices, or `ryoku-hub rice apply %s`.\n", r.Slug)
	return b.String()
}

// runExportRice prints the destination folder for the Hub.
func runExportRice(slug, dest string) error {
	out, err := exportRice(slug, dest)
	if err != nil {
		return err
	}
	return printJSON(map[string]string{"path": out})
}

// --- edit / delete / fork --------------------------------------------------

func validRiceSlug(slug string) bool {
	return slug != "" && !strings.HasPrefix(slug, ".") && !strings.ContainsAny(slug, "/\\")
}

func deleteRice(slug string) error {
	if !validRiceSlug(slug) {
		return fmt.Errorf("bad rice slug %q", slug)
	}
	if slug == activeRice() {
		setActiveRice("")
	}
	return os.RemoveAll(filepath.Join(ricesDir(), slug))
}

// saveRiceJSON persists an edited manifest sent by the Hub's rice editor.
func saveRiceJSON(s string) error {
	var r Rice
	if err := json.Unmarshal([]byte(s), &r); err != nil {
		return fmt.Errorf("parse rice JSON: %w", err)
	}
	if !validRiceSlug(r.Slug) {
		return fmt.Errorf("rice needs a valid slug")
	}
	if r.Schema == 0 {
		r.Schema = riceSchema
	}
	return saveRice(r)
}

// forkRice duplicates a rice (and its bundled assets) under a fresh slug, so a
// shipped or installed rice can be tweaked without touching the original.
func forkRice(slug string) (Rice, error) {
	r, dir, err := loadRice(slug)
	if err != nil {
		return r, err
	}
	newSlug := slug + "-copy"
	for i := 2; isFile(ricePath(newSlug)); i++ {
		newSlug = fmt.Sprintf("%s-copy-%d", slug, i)
	}
	newDir := filepath.Join(ricesDir(), newSlug)
	entries, _ := os.ReadDir(dir)
	for _, e := range entries {
		if e.IsDir() || e.Name() == "rice.json" {
			continue
		}
		_ = copyFile(filepath.Join(dir, e.Name()), filepath.Join(newDir, e.Name()))
	}
	r.Slug = newSlug
	r.Name = strings.TrimSpace(r.Name) + " copy"
	return r, saveRice(r)
}

// --- dispatch --------------------------------------------------------------

func runRice(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("rice needs list|capture|apply|restore|save|fork|delete|catalog|install|publish|setwall|files|export")
	}
	switch args[0] {
	case "list":
		return printJSON(listRiceEntries())
	case "capture":
		if len(args) < 2 {
			return fmt.Errorf("rice capture needs a name")
		}
		r, err := captureRice(args[1], args[2:])
		if err != nil {
			return err
		}
		return printJSON(r)
	case "apply":
		if len(args) < 2 {
			return fmt.Errorf("rice apply needs a slug")
		}
		if err := applyRice(args[1], args[2:]); err != nil {
			return err
		}
		setActiveRice(args[1])
		return nil
	case "restore":
		slot := ".baseline"
		if len(args) >= 2 && args[1] == "previous" {
			slot = ".previous"
		}
		if err := restoreRice(slot); err != nil {
			return err
		}
		setActiveRice("")
		return nil
	case "save":
		if len(args) < 2 {
			return fmt.Errorf("rice save needs a JSON argument")
		}
		return saveRiceJSON(args[1])
	case "fork":
		if len(args) < 2 {
			return fmt.Errorf("rice fork needs a slug")
		}
		nr, err := forkRice(args[1])
		if err != nil {
			return err
		}
		return printJSON(nr)
	case "delete":
		if len(args) < 2 {
			return fmt.Errorf("rice delete needs a slug")
		}
		return deleteRice(args[1])
	case "catalog":
		items, err := catalogRices()
		if err != nil {
			return err
		}
		return printJSON(items)
	case "install":
		if len(args) < 2 {
			return fmt.Errorf("rice install needs an id")
		}
		return installRice(args[1])
	case "publish":
		if len(args) < 3 {
			return fmt.Errorf("rice publish needs a slug and a store path")
		}
		return publishRice(args[1], args[2])
	case "setwall":
		if len(args) < 3 {
			return fmt.Errorf("rice setwall needs a slug and an image path")
		}
		return setRiceWallpaper(args[1], args[2])
	case "files":
		if len(args) < 2 {
			return fmt.Errorf("rice files needs a slug")
		}
		return riceFiles(args[1])
	case "export":
		if len(args) < 3 {
			return fmt.Errorf("rice export needs a slug and a destination folder")
		}
		return runExportRice(args[1], args[2])
	default:
		return fmt.Errorf("unknown rice subcommand: %s", args[0])
	}
}
