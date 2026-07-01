package main

import (
	"encoding/json"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// the wallpaper daemon. constant so swapping it (swww etc.) is a one-line change.
const (
	wallDaemon      = "awww"
	wallDaemonStart = "awww-daemon"
)

func wallDir() string   { return filepath.Join(os.Getenv("HOME"), "Pictures", "Wallpapers") }
func wallState() string { return filepath.Join(stateDir(), "ryoku-wallpaper") }
func wallBag() string   { return filepath.Join(stateDir(), "ryoku-wallpaper-bag") }

// transition = flags appended after `awww img <pic>`. Super+W picks one at random
// so consecutive switches feel varied.
type transition struct {
	name string
	args []string
}

// shared transition speed: every Super+W transition runs the same wall-clock
// duration, only the shape (type / easing / edge) varies. awww binds non-'simple'
// transitions to elapsed time, so duration alone sets speed; fps = smoothness
// (panel is 165Hz).
const (
	transitionDuration = "2.2"
	transitionFPS      = "144"
)

// awww transition shapes Super+W cycles through; showWallpaper appends the shared
// duration / fps. mechanics: sweep timing = --transition-duration + bezier + fps.
// for geometric/wipe/wave, --transition-step is edge softness only (low = feathered
// band, high = crisp); 'fade' ignores it. beziers stay monotonic (y in [0,1]) so
// 'fade' never wraps its alpha.
var transitionPresets = []transition{
	// crossfade
	{"silk_fade", []string{ // crossfade, easeInOutCubic
		"--transition-type", "fade",
		"--transition-bezier", "0.65,0,0.35,1",
	}},
	// directional sweeps (wipe / wave)
	{"diagonal_silk", []string{ // 30deg wipe, fast launch then glide, easeOutExpo
		"--transition-type", "wipe", "--transition-angle", "30",
		"--transition-bezier", "0.16,1,0.3,1", "--transition-step", "110",
	}},
	{"dream_curtain", []string{ // top-down curtain, soft feathered edge, easeInOutQuint
		"--transition-type", "wipe", "--transition-angle", "90",
		"--transition-bezier", "0.83,0,0.17,1", "--transition-step", "35",
	}},
	{"liquid_ribbon", []string{ // diagonal rolling waves, easeInOutQuart
		"--transition-type", "wave", "--transition-angle", "45",
		"--transition-wave", "25,35",
		"--transition-bezier", "0.76,0,0.24,1", "--transition-step", "90",
	}},
	// circle reveals (center / grow / outer / any)
	{"iris_open", []string{ // iris bloom from dead center, easeOutQuint
		"--transition-type", "center",
		"--transition-bezier", "0.22,1,0.36,1", "--transition-step", "100",
	}},
	{"corner_bloom", []string{ // blooms from bottom-left, easeOutExpo
		"--transition-type", "grow", "--transition-pos", "bottom-left",
		"--transition-bezier", "0.16,1,0.3,1", "--transition-step", "90",
	}},
	{"spotlight_rise", []string{ // swells up from bottom-center, easeOutCirc
		"--transition-type", "grow", "--transition-pos", "bottom",
		"--transition-bezier", "0,0.55,0.45,1", "--transition-step", "90",
	}},
	{"wander_iris", []string{ // bloom from a random on-screen point, easeOutQuart
		"--transition-type", "any",
		"--transition-bezier", "0.25,1,0.5,1", "--transition-step", "100",
	}},
	{"vignette_close", []string{ // new image seals from edges to center, easeInOutCubic
		"--transition-type", "outer",
		"--transition-bezier", "0.65,0,0.35,1", "--transition-step", "90",
	}},
}

// wallpaperApply: pick a wallpaper per mode (init | set | next | refresh) and show
// it. hot path runs the transition only; the slow retheme (palette, borders, LEDs)
// goes to coalescing background workers via scheduleTheme so rapid Super+W stays
// smooth. best-effort: a missing wallpaper dir or daemon is a no-op, not an error.
func (d *daemon) wallpaperApply(mode, arg string) error {
	// only init cares if a wallpaper is already up; next/set skip the extra probe
	// and let ensureWallDaemon do the single check.
	if mode == "init" && wallDaemonAlive() {
		return nil
	}
	if !ensureWallDaemon() {
		return nil
	}

	// refresh = repaint the current wallpaper on every output with no transition
	// (hotplug fills the new monitor without re-animating the rest). palette
	// already matches, so no retheme / state write.
	if mode == "refresh" {
		pic := readState()
		if pic == "" || !isFile(pic) {
			pic = popBag()
		}
		if pic == "" {
			return nil
		}
		return d.showWallpaperInstant(pic)
	}

	var pic string
	switch mode {
	case "init":
		if cur := readState(); cur != "" && isFile(cur) {
			pic = cur
		} else {
			pic = popBag()
		}
	case "set":
		if !isFile(arg) {
			return nil
		}
		pic = arg
	default: // next
		pic = popBag()
	}
	if pic == "" {
		return nil
	}

	if err := d.showWallpaper(pic); err != nil {
		return err
	}
	_ = os.MkdirAll(stateDir(), 0o755)
	_ = os.WriteFile(wallState(), []byte(pic+"\n"), 0o644)
	d.scheduleTheme()
	return nil
}

// showWallpaper: hand the image to awww with a random preset at the shared speed.
// returns once awww accepts it (~100ms); the daemon animates on its own, so this
// never blocks for the full transition.
func (d *daemon) showWallpaper(pic string) error {
	argv := append([]string{"img", pic}, d.pickTransition()...)
	argv = append(argv, "--transition-duration", transitionDuration, "--transition-fps", transitionFPS)
	return exec.Command(wallDaemon, argv...).Run()
}

// showWallpaperInstant: paint on every output, no transition. used on hotplug so
// a new monitor catches up without re-animating the others.
func (d *daemon) showWallpaperInstant(pic string) error {
	return exec.Command(wallDaemon, "img", pic, "--transition-type", "none").Run()
}

// pickTransition: random preset, never the previous one (consecutive switches
// shouldn't feel samey). called under wallMu, so lastTransition is fine bare.
func (d *daemon) pickTransition() []string {
	n := len(transitionPresets)
	if n == 0 {
		return nil
	}
	i := rand.Intn(n)
	if n > 1 && i == d.lastTransition {
		i = (i + 1 + rand.Intn(n-1)) % n
	}
	d.lastTransition = i
	return transitionPresets[i].args
}

// scheduleTheme: nudge the palette/border worker, non-blocking. buffered channel
// coalesces a burst into the latest, so theming runs once the presses settle.
func (d *daemon) scheduleTheme() {
	select {
	case d.paintSig <- struct{}{}:
	default:
	}
}

// paintWorker: regen the wallust palette for whatever is on screen, reload hypr
// (config-only, monitors untouched), wake the LED worker. `wallust run` rewrites
// every template in wallust.toml: kitty + hypr colors, and the shell palette at
// ~/.cache/wallust/colors.json the desktop visualiser live-watches, so its
// spectrum retunes to the wallpaper too. reads state every pass, so a coalesced
// burst themes the final wallpaper. runs for the life of the daemon.
func (d *daemon) paintWorker() {
	for range d.paintSig {
		pic := readState()
		if pic == "" || !isFile(pic) {
			continue
		}
		// fixed-palette theme (Ryoku Settings) owns the colours: change the image
		// but keep the locked palette, don't re-derive.
		if themePaletteLocked() {
			continue
		}
		_ = exec.Command("wallust", append([]string{"run", pic}, tuneArgs()...)...).Run()
		_ = exec.Command("hyprctl", "reload", "config-only").Run()
		select {
		case d.ledsSig <- struct{}{}:
		default:
		}
	}
}

// themePaletteLocked: does a Ryoku Settings theme own the colours (so a wallpaper
// change keeps them). state at ~/.config/ryoku/theme.json; colours locked when
// the source doesn't follow the wallpaper.
func themePaletteLocked() bool {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".config")
	}
	b, err := os.ReadFile(filepath.Join(base, "ryoku", "theme.json"))
	if err != nil {
		return false
	}
	// default true when absent (shipped behaviour = follow the wallpaper).
	s := struct {
		FollowWallpaper bool `json:"followWallpaper"`
	}{FollowWallpaper: true}
	return json.Unmarshal(b, &s) == nil && !s.FollowWallpaper
}

// wallustTune: the wallhaven app's saved look. when present, its fields append to
// `wallust run` so a set wallpaper (and later Super+W cycles) match what the app
// previewed. absent or empty fields fall back to the wallust config.
func wallustTune() string { return filepath.Join(stateDir(), "ryoku-wallust.json") }

func tuneArgs() []string {
	b, err := os.ReadFile(wallustTune())
	if err != nil {
		return nil
	}
	var t struct {
		Image      string `json:"image"`
		Palette    string `json:"palette"`
		Colorspace string `json:"colorspace"`
		Backend    string `json:"backend"`
		Saturation int    `json:"saturation"`
		Threshold  int    `json:"threshold"`
		Contrast   bool   `json:"contrast"`
	}
	if json.Unmarshal(b, &t) != nil {
		return nil
	}
	// per-image: the tune only applies to the image it was set on. a plain
	// wallpaper change (Super+W, a different image) no longer matches, so it
	// falls back to default extraction. keyed by path, a stale tune can never
	// bleed onto another wallpaper.
	if t.Image == "" || t.Image != readState() {
		return nil
	}
	var a []string
	if isWallustName(t.Palette) {
		a = append(a, "-p", t.Palette)
	}
	if isWallustName(t.Colorspace) {
		a = append(a, "-c", t.Colorspace)
	}
	if isWallustName(t.Backend) {
		a = append(a, "-b", t.Backend)
	}
	if t.Saturation >= 1 && t.Saturation <= 100 {
		a = append(a, "--saturation", strconv.Itoa(t.Saturation))
	}
	if t.Threshold >= 1 && t.Threshold <= 100 {
		a = append(a, "-t", strconv.Itoa(t.Threshold))
	}
	if t.Contrast {
		a = append(a, "-k")
	}
	return a
}

// isWallustName: every wallust enum value is a short lowercase-alphanumeric token.
// reject anything else so a stray tune file can't feed odd args to the process.
func isWallustName(s string) bool {
	if s == "" || len(s) > 32 {
		return false
	}
	for _, r := range s {
		if !((r >= 'a' && r <= 'z') || (r >= '0' && r <= '9')) {
			return false
		}
	}
	return true
}

// ledsWorker: push accent to OpenRGB. detection is slow (seconds), so it lives on
// its own coalescing worker and never touches the wallpaper hot path. runs for
// the life of the daemon.
func (d *daemon) ledsWorker() {
	for range d.ledsSig {
		_ = exec.Command("ryoku-leds", "apply").Run()
	}
}

func wallDaemonAlive() bool {
	return exec.Command(wallDaemon, "query").Run() == nil
}

func ensureWallDaemon() bool {
	if wallDaemonAlive() {
		return true
	}
	for attempt := 0; attempt < 5; attempt++ {
		cmd := exec.Command(wallDaemonStart)
		_ = cmd.Start()
		if cmd.Process != nil {
			_ = cmd.Process.Release()
		}
		for i := 0; i < 15; i++ {
			if wallDaemonAlive() {
				return true
			}
			time.Sleep(200 * time.Millisecond)
		}
	}
	return false
}

func listPics() []string {
	root := wallDir()
	if resolved, err := filepath.EvalSymlinks(root); err == nil {
		root = resolved
	}
	var pics []string
	_ = filepath.WalkDir(root, func(p string, info os.DirEntry, err error) error {
		if err != nil || info.IsDir() {
			return nil
		}
		switch strings.ToLower(filepath.Ext(p)) {
		case ".jpg", ".jpeg", ".png", ".webp":
			pics = append(pics, p)
		}
		return nil
	})
	return pics
}

// popBag: next wallpaper out of a shuffled bag. refills + reshuffles when empty
// so every wallpaper shows once per cycle.
func popBag() string {
	for refilled := false; ; {
		lines := readLines(wallBag())
		if len(lines) == 0 {
			if refilled {
				return ""
			}
			refillBag()
			refilled = true
			continue
		}
		pic := lines[0]
		writeLines(wallBag(), lines[1:])
		if isFile(pic) {
			return pic
		}
	}
}

func refillBag() {
	pics := listPics()
	if len(pics) == 0 {
		return
	}
	rand.Shuffle(len(pics), func(i, j int) { pics[i], pics[j] = pics[j], pics[i] })
	if cur := readState(); cur != "" && len(pics) > 1 && pics[0] == cur {
		pics = append(pics[1:], cur)
	}
	_ = os.MkdirAll(stateDir(), 0o755)
	writeLines(wallBag(), pics)
}

func readState() string {
	b, err := os.ReadFile(wallState())
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func readLines(path string) []string {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil
	}
	var out []string
	for _, l := range strings.Split(string(b), "\n") {
		if l = strings.TrimSpace(l); l != "" {
			out = append(out, l)
		}
	}
	return out
}

func writeLines(path string, lines []string) {
	data := ""
	if len(lines) > 0 {
		data = strings.Join(lines, "\n") + "\n"
	}
	_ = os.WriteFile(path, []byte(data), 0o644)
}

func isFile(p string) bool {
	st, err := os.Stat(p)
	return err == nil && !st.IsDir()
}
