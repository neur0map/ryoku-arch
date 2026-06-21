package main

import (
	"encoding/json"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// The wallpaper daemon Ryoku drives. Kept as a constant so swapping it (swww, etc.)
// is a one-line change.
const (
	wallDaemon      = "awww"
	wallDaemonStart = "awww-daemon"
)

func wallDir() string   { return filepath.Join(os.Getenv("HOME"), "Pictures", "Wallpapers") }
func wallState() string { return filepath.Join(stateDir(), "ryoku-wallpaper") }
func wallBag() string   { return filepath.Join(stateDir(), "ryoku-wallpaper-bag") }

// transition is one hand-tuned awww transition flavour: the flags appended after
// `awww img <pic>`. Super+W picks one at random per change so switches feel varied.
type transition struct {
	name string
	args []string
}

// transitionSpeed: every Super+W transition runs for the same wall-clock duration
// so they share one speed; only the shape (type, easing, edge) varies per preset.
// awww binds each non-'simple' transition to elapsed time, so duration alone sets
// the speed; fps is smoothness only (the panel runs at 165Hz).
const (
	transitionDuration = "2.2"
	transitionFPS      = "144"
)

// transitionPresets are hand-tuned, source-verified awww transition shapes Super+W
// cycles through; showWallpaper appends the shared duration/fps. Mechanics that
// matter: sweep timing is set by --transition-duration + --transition-bezier +
// --transition-fps; for geometric/wipe/wave types --transition-step only sets edge
// softness (low = a dreamy feathered band, high = a crisp edge), and 'fade' ignores
// it entirely. Beziers stay monotonic (y in [0,1]) so 'fade' never wraps its alpha.
var transitionPresets = []transition{
	// Crossfade.
	{"silk_fade", []string{ // calm even crossfade, easeInOutCubic
		"--transition-type", "fade",
		"--transition-bezier", "0.65,0,0.35,1",
	}},
	// Directional sweeps (wipe/wave).
	{"diagonal_silk", []string{ // 30deg wipe, launches fast and glides to rest, easeOutExpo
		"--transition-type", "wipe", "--transition-angle", "30",
		"--transition-bezier", "0.16,1,0.3,1", "--transition-step", "110",
	}},
	{"dream_curtain", []string{ // top-to-bottom curtain with a soft feathered edge, easeInOutQuint
		"--transition-type", "wipe", "--transition-angle", "90",
		"--transition-bezier", "0.83,0,0.17,1", "--transition-step", "35",
	}},
	{"liquid_ribbon", []string{ // broad diagonal rolling waves, easeInOutQuart
		"--transition-type", "wave", "--transition-angle", "45",
		"--transition-wave", "25,35",
		"--transition-bezier", "0.76,0,0.24,1", "--transition-step", "90",
	}},
	// Circle reveals (center/grow/outer/any).
	{"iris_open", []string{ // camera-iris bloom from dead center, easeOutQuint
		"--transition-type", "center",
		"--transition-bezier", "0.22,1,0.36,1", "--transition-step", "100",
	}},
	{"corner_bloom", []string{ // blooms from the lower-left corner, easeOutExpo
		"--transition-type", "grow", "--transition-pos", "bottom-left",
		"--transition-bezier", "0.16,1,0.3,1", "--transition-step", "90",
	}},
	{"spotlight_rise", []string{ // circle swells up from bottom-center, easeOutCirc
		"--transition-type", "grow", "--transition-pos", "bottom",
		"--transition-bezier", "0,0.55,0.45,1", "--transition-step", "90",
	}},
	{"wander_iris", []string{ // bloom from a random on-screen point, easeOutQuart
		"--transition-type", "any",
		"--transition-bezier", "0.25,1,0.5,1", "--transition-step", "100",
	}},
	{"vignette_close", []string{ // new image seals in from the edges to center, easeInOutCubic
		"--transition-type", "outer",
		"--transition-bezier", "0.65,0,0.35,1", "--transition-step", "90",
	}},
}

// wallpaperApply selects a wallpaper per mode (init, set, next) and shows it. Only
// the visible transition runs on this hot path; the slow retheme (palette, border
// colors, LEDs) is handed to the coalescing background workers via scheduleTheme,
// so rapid Super+W presses stay smooth. Best-effort: a missing wallpaper directory
// or daemon is a no-op rather than an error.
func (d *daemon) wallpaperApply(mode, arg string) error {
	// Only init cares whether a wallpaper is already on screen; next/set skip the
	// extra liveness probe and let ensureWallDaemon do the single check.
	if mode == "init" && wallDaemonAlive() {
		return nil
	}
	if !ensureWallDaemon() {
		return nil
	}

	// refresh repaints the current wallpaper on every output with no transition, so
	// a freshly connected monitor shows the same image without re-animating the
	// others. The palette already matches, so it skips the retheme and state write.
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

// showWallpaper sends the image to the wallpaper daemon with a random transition
// preset at the shared transition speed. It returns once the daemon accepts the
// image (~100ms); the daemon animates on its own, so this never blocks for the
// whole transition.
func (d *daemon) showWallpaper(pic string) error {
	argv := append([]string{"img", pic}, d.pickTransition()...)
	argv = append(argv, "--transition-duration", transitionDuration, "--transition-fps", transitionFPS)
	return exec.Command(wallDaemon, argv...).Run()
}

// showWallpaperInstant paints the wallpaper on every output with no transition.
// Used on monitor hotplug to fill a newly connected output without re-animating
// the displays that already show it.
func (d *daemon) showWallpaperInstant(pic string) error {
	return exec.Command(wallDaemon, "img", pic, "--transition-type", "none").Run()
}

// pickTransition returns a random preset's flags, never the previous one so
// consecutive switches feel varied. Called under wallMu, so lastTransition needs
// no extra guard.
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

// scheduleTheme wakes the palette/border worker without blocking. The buffered
// channel coalesces a burst of changes into the latest one, so theming runs once
// the presses settle rather than once per press.
func (d *daemon) scheduleTheme() {
	select {
	case d.paintSig <- struct{}{}:
	default:
	}
}

// paintWorker regenerates the wallust palette for the wallpaper on screen, reloads
// the Hyprland config so the border colors follow it (config-only, so the monitors
// are left alone), and wakes the LED worker. `wallust run` rewrites every template
// in wallust.toml: the kitty and Hyprland colors, and the shell palette at
// ~/.cache/wallust/colors.json that the desktop visualiser live-watches, so its
// spectrum retunes to the wallpaper here too. It reads the state file each pass, so
// a coalesced burst themes the final wallpaper. Runs for the life of the daemon.
func (d *daemon) paintWorker() {
	for range d.paintSig {
		pic := readState()
		if pic == "" || !isFile(pic) {
			continue
		}
		// A fixed-palette theme (Ryoku Settings) owns the colours: change the
		// wallpaper image but keep the theme palette instead of re-deriving it.
		if themePaletteLocked() {
			continue
		}
		_ = exec.Command("wallust", "run", pic).Run()
		_ = exec.Command("hyprctl", "reload", "config-only").Run()
		select {
		case d.ledsSig <- struct{}{}:
		default:
		}
	}
}

// themePaletteLocked reports whether a Ryoku Settings theme owns the colours, so a
// wallpaper change keeps them. State at ~/.config/ryoku/theme.json: colours are
// locked when the colour source does not follow the wallpaper.
func themePaletteLocked() bool {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".config")
	}
	b, err := os.ReadFile(filepath.Join(base, "ryoku", "theme.json"))
	if err != nil {
		return false
	}
	// Default true when absent (the shipped behaviour follows the wallpaper).
	s := struct {
		FollowWallpaper bool `json:"followWallpaper"`
	}{FollowWallpaper: true}
	return json.Unmarshal(b, &s) == nil && !s.FollowWallpaper
}

// ledsWorker pushes the accent color to OpenRGB devices. OpenRGB device detection
// is slow (seconds), so it lives on its own coalescing worker and never touches
// the wallpaper hot path. Runs for the life of the daemon.
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

// popBag returns the next wallpaper from a shuffled bag, refilling and reshuffling
// when the bag runs out so every wallpaper shows once per cycle.
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
