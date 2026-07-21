package main

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync/atomic"
	"time"
)

// the wallpaper daemon. awww (swww renamed upstream) now ships from the [ryoku]
// repo as a hard ryoku-desktop dependency, so `ryoku update` installs it on every
// box; older installs may still carry the AUR swww or awww-git, whose binary
// provides the same name. use whichever this box actually has (awww preferred).
// the CLI is identical between them, so the transition presets work either way.
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
	// live-reload = relaunch the current live wallpaper with fresh motion opts
	// (ryowalls changed the fit). phonto only, so it needs no image daemon; no
	// state write and no retheme, just a restart.
	if mode == "live-reload" {
		if cur := readState(); isVideo(cur) && isFile(cur) {
			return d.showLiveWallpaper(cur)
		}
		return nil
	}
	// only init cares if a wallpaper is already up. a video is the exception:
	// its phonto may have died with the previous session, so relaunch it (phonto,
	// no awww). a live wallpaper never starts awww, which is why the set/next
	// paths below must not depend on it.
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

	// backend by file type. a video plays through phonto and never touches the
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
		return fmt.Errorf("the wallpaper daemon (%s) is not available; install awww (or run `ryoku doctor` to heal it)", wallDaemon)
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

// showWallpaperFade: crossfade to an image with a plain fade (not a random
// preset). used to settle awww onto a live clip's first frame, so switching
// image->live reads as a crossfade rather than a hard cut before the video daemon
// fades in on top of it (matching the Hyprland wallpaper-crossfade layer rule).
func (d *daemon) showWallpaperFade(pic string) error {
	return exec.Command(wallDaemon, "img", pic,
		"--transition-type", "fade",
		"--transition-duration", transitionDuration,
		"--transition-fps", transitionFPS).Run()
}

// --- live (video) wallpapers: awww still + the ryoku-livewall daemon ---------
//
// A video plays through ryoku-livewall, a lightweight software-decode daemon that
// paints wl_shm frames on its own wlr background surface. It maps no GPU/EGL
// driver, so it holds ~40 MB RSS on any vendor, where mpv/mpvpaper (a client GL
// pipeline) cost 300-700 MB and leak per loop, and hardware decode cannot beat it
// on NVIDIA (the CUDA/GL userspace floor alone exceeds 100 MB). awww stays up
// under it showing the clip's own first frame, so the desktop always shows the
// clip's content: livewall's video covers awww; the gap before it paints (a
// one-time transcode) is the clip's still, never a stale image; and switching back
// to an image transitions from that real frame.

const liveDaemon = "ryoku-livewall"

// liveCapWidth caps livewall's decode/render width at the widest monitor's
// logical width (physical / fractional scale), so a video wallpaper renders near
// 1:1 with its surface instead of the old fixed 1280 upscaled to a blur. Software
// decode scales with resolution, so the width is clamped to 2560 to hold
// livewall's PSS under the 100 MB budget (~57 MB at 2048, ~78 MB at 2560); a
// wider panel plays at 2560 rather than blow it. "1920" when hyprctl is absent.
func liveCapWidth() string {
	const floor, ceil = 1280, 2560
	out, err := exec.Command("hyprctl", "monitors", "-j").Output()
	if err != nil {
		return "1920"
	}
	var mons []struct {
		Width int     `json:"width"`
		Scale float64 `json:"scale"`
	}
	if json.Unmarshal(out, &mons) != nil {
		return "1920"
	}
	best := 0
	for _, m := range mons {
		w := m.Width
		if m.Scale > 0 {
			w = int(float64(m.Width)/m.Scale + 0.5)
		}
		if w > best {
			best = w
		}
	}
	if best < floor {
		best = floor
	}
	if best > ceil {
		best = ceil
	}
	return strconv.Itoa(best)
}

// liveFit reads the ryowalls Fit knob (ryowalls.json) that livewall applies when
// mapping the clip onto the screen: "fit" letterboxes the whole clip, the
// default covers. Passed to livewall as argv[3]; a missing config means cover.
func liveFit() string {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".config")
	}
	b, err := os.ReadFile(filepath.Join(base, "ryoku", "ryowalls.json"))
	if err != nil {
		return "fill"
	}
	var s struct {
		LiveFit string `json:"liveFit"`
	}
	if json.Unmarshal(b, &s) == nil && s.LiveFit == "fit" {
		return "fit"
	}
	return "fill"
}

// liveGen serializes the async transcode+launch: every live-set or stop bumps it,
// and a transcode goroutine launches livewall only if its generation is still
// current, so a clip the user already switched away from never paints.
var liveGen atomic.Int64

func isVideo(p string) bool {
	switch strings.ToLower(filepath.Ext(p)) {
	case ".mp4", ".webm", ".mkv", ".mov":
		return true
	}
	return false
}

func liveAlive() bool { return exec.Command("pgrep", "-x", liveDaemon).Run() == nil }

// legacyLiveDaemons: video backends previous releases shipped (mpvpaper through
// beta 16, phonto in the interim GPU-picked era). an update swaps the daemon
// binary but not the detached player the old daemon left running, and that
// orphan's background surface stacks ABOVE awww's, so every static set paints
// invisibly under the old clip ("the wallpaper won't change"). nothing else
// manages them anymore, so killLegacyLive reaps them where the daemon takes
// ownership of the wallpaper stack: once at bootstrap (wallInit), and in the
// updater's quiesce. NOT in killLive: an orphan cannot appear mid-session (no
// old daemon is left to spawn one), and livewall is single-output today, so a
// user may legitimately run mpvpaper on a second monitor -- reaping on every
// wallpaper change would kill that setup over and over.
var legacyLiveDaemons = []string{"mpvpaper", "phonto"}

func killLegacyLive() {
	for _, name := range legacyLiveDaemons {
		_ = exec.Command("pkill", "-x", name).Run()
	}
}

// wallInit is the daemon's first wallpaper pass, under wallMu in bootstrap.
// the legacy reap must precede the init apply: with a static state and awww
// alive, init returns without reaching any kill path, and the orphan would
// keep occluding the desktop until the user's next wallpaper change.
func (d *daemon) wallInit() {
	killLegacyLive()
	_ = d.wallpaperApply("init", "")
}

// killLive terminates every livewall instance and waits for it to exit, so a
// following awww image or a fresh instance is never raced by a lingering one.
func killLive() {
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

// stopLive stops the video and cancels any in-flight transcode (the generation
// bump), so switching to an image never lets a late transcode relaunch livewall
// over the new wallpaper.
func stopLive() {
	liveGen.Add(1)
	killLive()
}

// showAny: route a video to the live path (awww still + video daemon) and an
// image to awww. an image set stops the video daemon so awww's still (the clip's
// frame, or the previous image) is revealed, and awww transitions from that real
// frame, never a stale cache.
func (d *daemon) showAny(pic string) error {
	if isVideo(pic) {
		return d.showLiveWallpaper(pic)
	}
	stopLive()
	return d.showWallpaper(pic)
}

// showLiveWallpaper: show a clip through awww's still + the ryoku-livewall daemon.
// awww paints the clip's own first frame and stays up under livewall, so the
// desktop always shows the clip's content: livewall's video covers awww; the gap
// before it paints (only a one-time transcode) is the clip's still, not a stale
// image or black; and a later switch to an image transitions from that real frame.
// It is also the whole wallpaper when livewall is not installed (the still alone).
func (d *daemon) showLiveWallpaper(pic string) error {
	gen := liveGen.Add(1)
	killLive() // stop the old video now; awww's frame shows under until the new paints
	if frame := liveFrame(pic); frame != "" && ensureWallDaemon() {
		_ = d.showWallpaperFade(frame)
	}
	if _, err := exec.LookPath(liveDaemon); err != nil {
		return nil // no livewall installed: the clip's still is the wallpaper
	}
	// Transcode (cached) and launch off the hot path: the first encode of a clip
	// takes a few seconds, during which awww holds the still; cached clips launch
	// at once. The generation guard drops the launch if the wallpaper changed while
	// the transcode ran.
	go func() {
		capW := liveCapWidth()
		src := livewallSource(pic, capW)
		if src == "" || liveGen.Load() != gen {
			return
		}
		cmd := exec.Command(liveDaemon, src, capW, liveFit())
		if cmd.Start() != nil {
			return
		}
		go func() { _ = cmd.Wait() }()
	}()
	return nil
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

// livewallSource: the cached H.264 that livewall decodes, transcoded once per
// clip + cap width (keyed by path, mtime and cap). Software-decoding the 4K
// source directly would blow the RAM budget; downscaling to the screen's width
// keeps livewall bounded while matching the panel, so the video is not upscaled
// to a blur. "" if ffmpeg fails, so the caller keeps the clip's still frame.
func livewallSource(pic, capW string) string {
	st, err := os.Stat(pic)
	if err != nil {
		return ""
	}
	base := os.Getenv("XDG_CACHE_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".cache")
	}
	dir := filepath.Join(base, "ryoku", "livewall")
	name := strings.TrimSuffix(filepath.Base(pic), filepath.Ext(pic))
	out := filepath.Join(dir, name+"-"+strconv.FormatInt(st.ModTime().Unix(), 10)+"-"+capW+".mp4")
	if isFile(out) {
		return out
	}
	if os.MkdirAll(dir, 0o755) != nil {
		return ""
	}
	// pid-unique tmp: two rapid sets of the same clip transcode concurrently
	// (the generation guard drops the launch, not the encode); a shared tmp
	// would interleave both writers into a corrupt cached video.
	tmp := out + ".tmp." + strconv.Itoa(os.Getpid()) + "-" + strconv.FormatInt(time.Now().UnixNano(), 10) + ".mp4"
	err = exec.Command("ffmpeg", "-y", "-i", pic,
		"-vf", "scale='min("+capW+",iw)':-2:flags=bicubic", "-r", "30",
		"-c:v", "libx264", "-preset", "veryfast", "-pix_fmt", "yuv420p", "-an", tmp).Run()
	if err != nil || !isFile(tmp) {
		_ = os.Remove(tmp)
		return ""
	}
	if os.Rename(tmp, out) != nil {
		_ = os.Remove(tmp)
		return ""
	}
	return out
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

// paintWorker: regen the palette for whatever is on screen, reload hypr
// (config-only, monitors untouched), wake the LED worker. `wallust run` extracts
// the palette to ~/.cache/wallust/colors.json (the desktop visualiser live-
// watches it, so its spectrum retunes too); renderApps then fans that one
// palette into every app config through matugen. reads state every pass, so a
// coalesced burst themes the final wallpaper. runs for the life of the daemon.
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
		// matugen fans the freshly extracted palette across the rest of the app
		// suite (GTK, Qt, btop) so a wallpaper change retints them too.
		renderApps()
		_ = exec.Command("hyprctl", "reload", "config-only").Run()
		select {
		case d.ledsSig <- struct{}{}:
		default:
		}
	}
}

// renderApps templates the external app configs (kitty, Hyprland, GTK, Qt, btop)
// from the freshly extracted ~/.cache/wallust/colors.json through matugen, the
// same engine the fixed schemes drive, so follow-the-wallpaper mode retints the
// whole suite and not just the shell, kitty, and borders.
func renderApps() {
	cache := os.Getenv("XDG_CACHE_HOME")
	if cache == "" {
		cache = filepath.Join(os.Getenv("HOME"), ".cache")
	}
	b, err := os.ReadFile(filepath.Join(cache, "wallust", "colors.json"))
	if err != nil {
		return
	}
	var pal map[string]string
	if json.Unmarshal(b, &pal) != nil {
		return
	}
	cols := map[string]any{}
	for k, v := range pal {
		cols[k] = map[string]any{"default": map[string]any{"hex": v}}
		cols[k+"_argb"] = map[string]any{"default": map[string]any{"hex": "#ff" + strings.TrimPrefix(v, "#")}}
	}
	cols["cursor"] = map[string]any{"default": map[string]any{"hex": pal["foreground"]}}
	carrier, err := json.Marshal(map[string]any{"colors": cols})
	if err != nil {
		return
	}
	dir := filepath.Join(cache, "ryoku")
	_ = os.MkdirAll(dir, 0o755)
	cpath := filepath.Join(dir, "matugen-carrier.json")
	if os.WriteFile(cpath, carrier, 0o644) != nil {
		return
	}
	cfgBase := os.Getenv("XDG_CONFIG_HOME")
	if cfgBase == "" {
		cfgBase = filepath.Join(os.Getenv("HOME"), ".config")
	}
	matugenDir := filepath.Join(cfgBase, "matugen")
	// core surface (terminal, frame, monitor, Qt) always tracks the palette.
	_ = exec.Command("matugen", "-c", filepath.Join(matugenDir, "config.toml"), "json", cpath).Run()
	// GTK / GUI apps only when "Theme apps" is on; else revert them to stock.
	if themeAppsEnabled() {
		_ = exec.Command("matugen", "-c", filepath.Join(matugenDir, "apps.toml"), "json", cpath).Run()
	} else {
		blankGtk(cfgBase)
	}
}

// themeAppsEnabled reports whether the palette should reach GTK / GUI apps.
// Mirrors the hub control plane: a theme.json without the key reads as on, so
// existing installs keep the themed apps they already had.
func themeAppsEnabled() bool {
	base := os.Getenv("XDG_CONFIG_HOME")
	if base == "" {
		base = filepath.Join(os.Getenv("HOME"), ".config")
	}
	b, err := os.ReadFile(filepath.Join(base, "ryoku", "theme.json"))
	if err != nil {
		return true
	}
	var s struct {
		ThemeApps *bool `json:"themeApps"`
	}
	if json.Unmarshal(b, &s) != nil || s.ThemeApps == nil {
		return true
	}
	return *s.ThemeApps
}

// blankGtk drops the Ryoku palette from the generated GTK stylesheets, so GTK /
// libadwaita apps fall back to their own stock colours when app theming is off.
func blankGtk(cfgBase string) {
	const off = "/* Ryoku: app theming is off; apps use their own colours. */\n"
	for _, rel := range []string{"gtk-3.0/gtk.css", "gtk-4.0/gtk.css"} {
		p := filepath.Join(cfgBase, rel)
		_ = os.MkdirAll(filepath.Dir(p), 0o755)
		_ = os.WriteFile(p, []byte(off), 0o644)
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
	// no daemon binary at all (say, the AUR build never landed): retrying the
	// start just burns ~15s per apply; fail fast so the caller can say why.
	if _, err := exec.LookPath(wallDaemonStart); err != nil {
		return false
	}
	for attempt := 0; attempt < 5; attempt++ {
		cmd := exec.Command(wallDaemonStart)
		if cmd.Start() == nil {
			// reap on exit so a later-killed daemon is never left a zombie (Release
			// would orphan it as <defunct> until the shell itself exits).
			go func() { _ = cmd.Wait() }()
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
