package main

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// the wallpaper daemon. swww was renamed to awww upstream; older installs still
// have swww while newer ones have awww, and `ryoku update` never pulls the AUR
// rename, so use whichever this box actually has (awww preferred). the CLI is
// identical between them, so the transition presets work either way.
var wallDaemon, wallDaemonStart = resolveWallDaemon()

func resolveWallDaemon() (cli, start string) {
	for _, d := range [][2]string{{"awww", "awww-daemon"}, {"swww", "swww-daemon"}} {
		if _, err := exec.LookPath(d[0]); err == nil {
			return d[0], d[1]
		}
		if _, err := exec.LookPath(d[1]); err == nil {
			return d[0], d[1]
		}
	}
	return "awww", "awww-daemon"
}

func wallDir() string   { return filepath.Join(os.Getenv("HOME"), "Pictures", "Wallpapers") }
func liveDir() string   { return filepath.Join(os.Getenv("HOME"), "Pictures", "livewalls") }
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
	// caelestia v2: Material 3 Expressive motion, ported from its shell's
	// animation tokens (v2.1.0 plugin/src/Caelestia/Config/tokens.hpp). caelestia
	// switches wallpapers with an opacity crossfade on the expressiveSlowEffects
	// curve, which celeste_veil reproduces exactly; its other monotonic signature
	// curves ride our geometric sweeps. Its springy *Spatial curves overshoot
	// (y>1) and its emphasized curve is a two-segment spline, neither of which
	// awww's single monotonic bezier can carry, so they are left out.
	{"celeste_veil", []string{ // caelestia's own wallpaper crossfade, expressiveSlowEffects
		"--transition-type", "fade",
		"--transition-bezier", "0.34,0.88,0.34,1",
	}},
	{"comet_streak", []string{ // fast-launch, long-glide sweep, emphasizedDecel
		"--transition-type", "wipe", "--transition-angle", "135",
		"--transition-bezier", "0.05,0.7,0.1,1", "--transition-step", "100",
	}},
	{"aurora_ripple", []string{ // snappy front-loaded wavy sweep, expressiveFastEffects
		"--transition-type", "wave", "--transition-angle", "120",
		"--transition-wave", "20,30",
		"--transition-bezier", "0.31,0.94,0.34,1", "--transition-step", "80",
	}},
	{"starfall_bloom", []string{ // iris blooming down from the top, M3 standard
		"--transition-type", "grow", "--transition-pos", "top",
		"--transition-bezier", "0.2,0,0,1", "--transition-step", "100",
	}},
}

// wallpaperApply: pick a wallpaper per mode (init | set | next | refresh) and show
// it. hot path runs the transition only; the slow retheme (palette, borders, LEDs)
// goes to coalescing background workers via scheduleTheme so rapid Super+W stays
// smooth. best-effort: a missing wallpaper dir or daemon is a no-op, not an error.
func (d *daemon) wallpaperApply(mode, arg string) error {
	// repaint = re-derive the palette / borders / LEDs for the current
	// wallpaper with no image transition. used by the hub when a settings
	// change (master toggle, theme) must re-theme without re-animating. needs
	// no wallpaper daemon: the paint worker reads state and runs wallust.
	if mode == "repaint" {
		d.scheduleTheme()
		return nil
	}
	// pause-sync = reconcile the live wallpaper's paused state (ryowalls toggled
	// pause-when-covered). mpvpaper only, so it needs no wallpaper daemon.
	if mode == "pause-sync" {
		livePauseReconcile()
		return nil
	}
	// only init cares if a wallpaper is already up. a video is the exception:
	// its mpvpaper died with the previous session, so relaunch it (mpvpaper, no
	// awww). a live wallpaper never starts awww, which is why the set/next paths
	// below must not depend on it.
	if mode == "init" {
		if cur := readState(); isVideo(cur) && isFile(cur) {
			if !liveAlive() {
				return d.showLiveWallpaper(cur)
			}
			return nil
		}
		if wallDaemonAlive() {
			return nil
		}
	}

	// resolve the target for this op before choosing a backend.
	var pic string
	switch mode {
	case "set":
		if !isFile(arg) {
			return nil
		}
		pic = arg
	case "refresh":
		pic = readState()
		if pic == "" || !isFile(pic) {
			pic = popBag()
		}
	case "init":
		if cur := readState(); cur != "" && isFile(cur) {
			pic = cur
		} else {
			pic = popBag()
		}
	default: // next
		pic = popBag()
	}
	if pic == "" {
		return nil
	}

	// backend by file type. a video plays through mpvpaper and never touches the
	// awww image daemon, so route it straight to the live backend: awww failing
	// to start must not silently drop a live wallpaper (it once gated every set).
	// refresh only repaints a hot-plugged output, so it skips the state write and
	// retheme; every other mode records the pick and re-themes.
	if isVideo(pic) {
		if err := d.showLiveWallpaper(pic); err != nil {
			return err
		}
		if mode == "refresh" {
			return nil
		}
		_ = os.MkdirAll(stateDir(), 0o755)
		_ = os.WriteFile(wallState(), []byte(pic+"\n"), 0o644)
		d.scheduleTheme()
		return nil
	}

	// images need awww, so its start-or-fail gate applies only from here on.
	if !ensureWallDaemon() {
		return nil
	}
	// refresh = repaint the current image on every output with no transition
	// (hotplug fills the new monitor without re-animating the rest). palette
	// already matches, so no retheme / state write.
	if mode == "refresh" {
		stopLive()
		return d.showWallpaperInstant(pic)
	}
	if err := d.showAny(pic); err != nil {
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

// --- live (video) wallpapers: mpvpaper over awww -----------------------------
//
// awww is image/GIF only, so a video plays through mpvpaper (mpv on the
// background layer), whose surface maps over awww's. Only one backend paints at a
// time: setting a video kills nothing of awww (it just covers it); setting an
// image kills mpvpaper so awww shows through.

const liveDaemon = "mpvpaper"

func isVideo(p string) bool {
	switch strings.ToLower(filepath.Ext(p)) {
	case ".mp4", ".webm", ".mkv", ".mov":
		return true
	}
	return false
}

func liveAlive() bool { return exec.Command("pgrep", "-x", liveDaemon).Run() == nil }
// stopLive terminates every mpvpaper and waits for it to exit, so a following
// awww image or a fresh mpvpaper is never raced by a lingering one: an async
// pkill let the old instance and a just-launched one coexist and leak.
func stopLive() {
	if exec.Command("pkill", "-x", liveDaemon).Run() != nil {
		return
	}
	for range 40 {
		if !liveAlive() {
			return
		}
		time.Sleep(25 * time.Millisecond)
	}
	_ = exec.Command("pkill", "-9", "-x", liveDaemon).Run()
}

// showAny: route a video to mpvpaper and an image to awww, stopping the other
// backend so exactly one paints.
func (d *daemon) showAny(pic string) error {
	if isVideo(pic) {
		return d.showLiveWallpaper(pic)
	}
	stopLive()
	return d.showWallpaper(pic)
}

// showLiveWallpaper: play the video, looping and muted, on the background layer.
// panscan fills the screen (a 16:9 clip letterboxes on a 16:10 panel otherwise).
// The IPC socket is how the daemon pauses it: mpvpaper's own auto-pause never
// fires under Hyprland, which keeps sending frame callbacks to covered layers.
func (d *daemon) showLiveWallpaper(pic string) error {
	// no mpvpaper installed: live playback is impossible, but the pick must still
	// apply, so degrade to a still frame shown through the image daemon. mpvpaper
	// stays a true optional enhancement (with it the wallpaper moves; without it
	// it is the clip's frame), so ryowalls reports success either way.
	if _, err := exec.LookPath(liveDaemon); err != nil {
		if frame := liveFrame(pic); frame != "" && ensureWallDaemon() {
			return d.showWallpaper(frame)
		}
		return nil
	}
	stopLive()
	sock := liveSockPath()
	_ = os.Remove(sock) // the killed instance's stale socket
	opts := "no-audio loop-file=inf hwdec=auto panscan=1.0 input-ipc-server=" + sock
	if err := exec.Command(liveDaemon, "-f", "-o", opts, "ALL", pic).Run(); err != nil {
		return err
	}
	// wait until mpvpaper is really up (its ipc socket appears) before returning,
	// so a later stopLive can see and kill it instead of racing a forking child.
	for range 80 {
		if _, err := os.Stat(sock); err == nil {
			break
		}
		time.Sleep(25 * time.Millisecond)
	}
	time.AfterFunc(time.Second, livePauseReconcile)
	return nil
}

func liveSockPath() string {
	if rt := os.Getenv("XDG_RUNTIME_DIR"); rt != "" {
		return filepath.Join(rt, "ryoku-mpvpaper.sock")
	}
	return "/tmp/ryoku-mpvpaper.sock"
}

// pause the live wallpaper while every monitor's desktop is covered, matching
// how the widget layer parks itself off desktopVisible. Stateless on purpose:
// uncovering any monitor resumes.
func livePauseReconcile() {
	sock := liveSockPath()
	if _, err := os.Stat(sock); err != nil {
		return
	}
	pause := livePauseWhenCovered() && !desktopVisible()
	conn, err := net.Dial("unix", sock)
	if err != nil {
		return
	}
	defer conn.Close()
	fmt.Fprintf(conn, `{"command":["set_property","pause",%t]}`+"\n", pause)
}

// liveFrame: one still from the video for wallust, which reads an image. offset
// defaults to a second in; the ryowalls frame slider can move it. "" on failure,
// so the palette just keeps its previous value.
func liveFrame(video string) string {
	out := filepath.Join(stateDir(), "ryoku-live-frame.png")
	err := exec.Command("ffmpeg", "-y", "-ss", frameOffset(video), "-i", video,
		"-frames:v", "1", out).Run()
	if err != nil || !isFile(out) {
		return ""
	}
	return out
}

// frameOffset: seconds into the video that wallust samples, from the per-video
// sticky tune; "1" by default.
func frameOffset(video string) string {
	b, err := os.ReadFile(wallustTune())
	if err != nil {
		return "1"
	}
	var t struct {
		Image string  `json:"image"`
		Frame float64 `json:"frame"`
	}
	if json.Unmarshal(b, &t) == nil && t.Image == video && t.Frame > 0 {
		return strconv.FormatFloat(t.Frame, 'f', 2, 64)
	}
	return "1"
}

// livePauseWhenCovered: the ryowalls toggle (off by default).
func livePauseWhenCovered() bool {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".config")
	}
	b, err := os.ReadFile(filepath.Join(base, "ryoku", "ryowalls.json"))
	if err != nil {
		return false
	}
	var s struct {
		PauseWhenCovered bool `json:"pauseWhenCovered"`
	}
	return json.Unmarshal(b, &s) == nil && s.PauseWhenCovered
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
		// wallust reads an image, so a video is themed off one extracted frame.
		src := pic
		if isVideo(pic) {
			if src = liveFrame(pic); src == "" {
				continue
			}
		}
		_ = exec.Command("wallust", append([]string{"run", src}, tuneArgs()...)...).Run()
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

// listPics: the Super+W pool. images from ~/Pictures/Wallpapers and videos from
// ~/Pictures/livewalls, so the switcher cycles both the same way.
func listPics() []string {
	var pics []string
	for _, root := range []string{wallDir(), liveDir()} {
		if resolved, err := filepath.EvalSymlinks(root); err == nil {
			root = resolved
		}
		_ = filepath.WalkDir(root, func(p string, info os.DirEntry, err error) error {
			if err != nil || info.IsDir() {
				return nil
			}
			switch strings.ToLower(filepath.Ext(p)) {
			case ".jpg", ".jpeg", ".png", ".webp", ".mp4", ".webm", ".mkv", ".mov":
				pics = append(pics, p)
			}
			return nil
		})
	}
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
