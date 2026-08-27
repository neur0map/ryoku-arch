package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math/rand"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync/atomic"
	"time"
)

func findHubBin() string {
	if p, err := exec.LookPath("ryoku-hub"); err == nil {
		return p
	}
	home := os.Getenv("HOME")
	for _, cand := range []string{
		filepath.Join(home, ".local", "bin", "ryoku-hub"),
		"/usr/local/bin/ryoku-hub",
		"/usr/bin/ryoku-hub",
	} {
		if _, err := os.Stat(cand); err == nil {
			return cand
		}
	}
	return "ryoku-hub"
}
func wallDir() string   { return filepath.Join(os.Getenv("HOME"), "Pictures", "Wallpapers") }
func liveDir() string   { return filepath.Join(os.Getenv("HOME"), "Pictures", "livewalls") }
func wallState() string { return filepath.Join(stateDir(), "ryoku-wallpaper") }
func wallBag() string   { return filepath.Join(stateDir(), "ryoku-wallpaper-bag") }

// wallpaperApply: pick a wallpaper per mode (init | set | next | random | refresh)
// show it. Images are painted by the in-shell backdrop surface (the daemon copies
// the pick into a cache file, bumps a revision, and publishes it); videos play
// through ryoku-livewall. The slow retheme (palette, borders, LEDs) goes to
// coalescing background workers via scheduleTheme so rapid Super+W stays smooth.
// best-effort: a missing wallpaper dir is a no-op, not an error.
func (d *daemon) wallpaperApply(mode, arg string) error {
	// repaint = re-derive the palette / borders / LEDs and re-fit the current
	// wallpaper (a settings change re-applies without re-animating). No image copy
	// or revision bump, so the backdrop re-fits with no crossfade.
	if mode == "repaint" {
		d.scheduleTheme()
		d.wall.republish()
		return nil
	}
	// live-reload = relaunch the current live wallpaper with fresh motion opts
	// (ryowalls changed the fit). Video only; no state write and no retheme.
	if mode == "live-reload" {
		if cur := readState(); isVideo(cur) && isFile(cur) {
			return d.showLiveWallpaper(cur)
		}
		return nil
	}
	// init: a saved live wallpaper's player either survived the daemon (adopt it,
	// no restart) or died with it (relaunch); a saved image is set below.
	if mode == "init" {
		if cur := readState(); isVideo(cur) && isFile(cur) {
			if liveAlive() {
				d.adoptLive(cur)
				return nil
			}
			return d.showLiveWallpaper(cur)
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
		// hotplug: a new monitor's backdrop window subscribes and paints the
		// current revision on its own, so there is nothing to repaint here.
		return nil
	case "random":
		// Super+Shift+W: a random wallpaper from the switcher pool, never the
		// current one. Includes live walls: the type branch below plays a video
		// through ryoku-livewall, or reveals an image with a random transition.
		pic = pickRandomImage(listPics(), readState())
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

	// A video plays through ryoku-livewall over its own still frame; an image is
	// revealed by the in-shell backdrop.
	if isVideo(pic) {
		if err := d.showLiveWallpaper(pic); err != nil {
			return err
		}
		_ = os.MkdirAll(stateDir(), 0o755)
		_ = os.WriteFile(wallState(), []byte(pic+"\n"), 0o644)
		d.scheduleTheme()
		return nil
	}

	// images: stop any video so the backdrop is revealed, then copy the pick into
	// the cache and bump the revision. A user-driven switch (set / next / random)
	// reveals with a random transition preset; init just crossfades onto the fresh
	// backdrop, so a login never fires a full reveal.
	d.stopLive()
	if err := d.wall.showTransition(pic, d.transitionFor(mode)); err != nil {
		return err
	}
	_ = os.MkdirAll(stateDir(), 0o755)
	_ = os.WriteFile(wallState(), []byte(pic+"\n"), 0o644)
	d.scheduleTheme()
	return nil
}

// --- live (video) wallpapers: the ryoku-livewall daemon ---------------------
//
// A video plays through ryoku-livewall, a lightweight software-decode daemon that
// paints wl_shm frames on its own wlr background surface. It maps no GPU/EGL
// driver, so it holds ~40 MB RSS on any vendor, where mpv/mpvpaper (a client GL
// pipeline) cost 300-700 MB and leak per loop, and hardware decode cannot beat it
// on NVIDIA (the CUDA/GL userspace floor alone exceeds 100 MB). The in-shell
// backdrop paints the clip's own first frame under it, so the desktop always shows
// the clip's content: livewall's video covers the backdrop; the gap before it
// paints (a one-time transcode) is the clip's still, never a stale image; and
// switching back to an image crossfades from that real frame.

const liveDaemon = "ryoku-livewall"

// liveCapWidth caps livewall's decode/render width at the widest monitor's
// logical width (physical / fractional scale), so a video wallpaper renders near
// 1:1 with its surface instead of the old fixed 1280 upscaled to a blur. Software
// decode scales with resolution, so the width is clamped to 2560 to hold
// livewall's PSS under the 100 MB budget (~47 MB at 2048, ~59 MB at 2560); a
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

// liveContentFit is liveFit() in the backdrop's vocabulary: the fillMode the clip's
// still must be painted in so the reveal is framed exactly like the video that
// replaces it. livewall's "fit" letterboxes the whole clip (Contain); its default
// covers the screen (Cover).
func liveContentFit() string {
	if liveFit() == "fit" {
		return "Contain"
	}
	return "Cover"
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
// over the new wallpaper. The backdrop takes the pixels back.
func (d *daemon) stopLive() {
	liveGen.Add(1)
	killLive()
	d.wall.setLive(false)
}

// showLiveWallpaper plays a clip through ryoku-livewall. It paints the clip's own
// first frame (a still) as the wallpaper, launches the player over it, and steps
// the backdrop aside once the player has actually painted (READY), so the desktop
// shows the clip's content throughout with no black seam. Without livewall the
// still alone is the wallpaper.
func (d *daemon) showLiveWallpaper(pic string) error {
	gen := liveGen.Add(1)
	killLive()
	if frame := liveFrame(pic); frame != "" {
		_ = d.wall.showFrame(frame, nil, liveContentFit())
	}
	if _, err := exec.LookPath(liveDaemon); err != nil {
		log.Printf("live wallpaper: %s not on PATH (build it with ryoku/shell/livewall/build.sh); showing the clip's still frame", liveDaemon)
		return nil
	}
	go func() {
		capW := liveCapWidth()
		src := livewallSource(pic, capW)
		if src == "" || liveGen.Load() != gen {
			return
		}
		cmd := exec.Command(liveDaemon, src, capW, liveFit())
		stdout, err := cmd.StdoutPipe()
		if err != nil || cmd.Start() != nil {
			return
		}
		// Step the backdrop aside only once the player has painted (READY); until
		// then the still holds the frame, so the hand-off shows no black seam. The
		// liveAlive guard keeps a player that died first on the still, not a hole.
		go func() {
			liveReady(stdout, 6*time.Second)
			if liveGen.Load() == gen && liveAlive() {
				d.wall.setLive(true)
			}
		}()
		_ = cmd.Wait()
		if liveGen.Load() == gen {
			d.wall.setLive(false)
		}
	}()
	return nil
}

// adoptLive re-publishes the live state for a clip whose player the previous daemon
// left running (KillMode=process orphans it on a restart). Without it the fresh
// daemon's empty snapshot lets the new backdrop cover the still-playing video and
// black the desktop. It republishes the still + live without restarting the
// player; the watcher drops live if that orphan later exits.
func (d *daemon) adoptLive(pic string) {
	gen := liveGen.Load()
	if frame := liveFrame(pic); frame != "" {
		_ = d.wall.showFrame(frame, nil, liveContentFit())
	}
	d.wall.setLive(true)
	go func() {
		for {
			select {
			case <-d.quit:
				return
			case <-time.After(2 * time.Second):
			}
			if liveGen.Load() != gen {
				return
			}
			if !liveAlive() {
				if liveGen.Load() == gen {
					d.wall.setLive(false)
				}
				return
			}
		}
	}()
}

// liveReady blocks until the player prints READY (its first painted frame), its
// stdout closes, or the timeout elapses, reporting whether READY was seen. It
// drains the pipe so the player never blocks on stdout.
func liveReady(stdout io.ReadCloser, timeout time.Duration) bool {
	seen := make(chan bool, 1)
	go func() {
		r := bufio.NewReader(stdout)
		got := false
		for {
			line, err := r.ReadString('\n')
			if !got && strings.TrimSpace(line) == "READY" {
				got = true
				seen <- true
			}
			if err != nil {
				if !got {
					seen <- false
				}
				return
			}
		}
	}()
	select {
	case ok := <-seen:
		return ok
	case <-time.After(timeout):
		return false
	}
}

// liveFrame: one still from the video, for the backdrop to hold while livewall
// starts and for matugen to read. Cached per clip, mtime and offset like the
// transcode is, and renamed into place. It used to be one shared file, so a
// ryowalls preview of another clip handed the daemon that clip's frame: the
// desktop showed the wrong video and took its light/dark from it. "" on failure,
// so the palette keeps its previous value.
func liveFrame(video string) string {
	st, err := os.Stat(video)
	if err != nil {
		return ""
	}
	off := frameOffset(video)
	dir := filepath.Join(stateDir(), "ryoku-live-frames")
	name := strings.TrimSuffix(filepath.Base(video), filepath.Ext(video))
	out := filepath.Join(dir, name+"-"+strconv.FormatInt(st.ModTime().Unix(), 10)+"-"+off+".png")
	if isFile(out) {
		return out
	}
	if os.MkdirAll(dir, 0o755) != nil {
		return ""
	}
	tmp := out + ".tmp." + strconv.Itoa(os.Getpid()) + "-" + strconv.FormatInt(time.Now().UnixNano(), 10) + ".png"
	// -update says "one image, not a sequence": without it ffmpeg 8 warns, and a
	// warning here is an error in the next release.
	err = exec.Command("ffmpeg", "-y", "-ss", off, "-i", video,
		"-frames:v", "1", "-update", "1", tmp).Run()
	if err != nil || !isFile(tmp) {
		_ = os.Remove(tmp)
		return ""
	}
	if os.Rename(tmp, out) != nil {
		_ = os.Remove(tmp)
		return ""
	}
	pruneLiveFrames(dir)
	return out
}

// pruneLiveFrames bounds the still cache: a 4K frame is a couple of MB and a
// wallpaper library grows.
const liveFrameKeep = 24

func pruneLiveFrames(dir string) {
	// the one shared still this cache replaced, on a box that still carries it
	_ = os.Remove(filepath.Join(stateDir(), "ryoku-live-frame.png"))
	ents, err := os.ReadDir(dir)
	if err != nil || len(ents) <= liveFrameKeep {
		return
	}
	type still struct {
		path string
		mod  time.Time
	}
	var stills []still
	for _, e := range ents {
		info, err := e.Info()
		if err != nil || e.IsDir() {
			continue
		}
		stills = append(stills, still{filepath.Join(dir, e.Name()), info.ModTime()})
	}
	if len(stills) <= liveFrameKeep {
		return
	}
	sort.Slice(stills, func(i, j int) bool { return stills[i].mod.After(stills[j].mod) })
	for _, s := range stills[liveFrameKeep:] {
		_ = os.Remove(s.path)
	}
}

// frameOffset: seconds into the video that matugen samples, from the per-video
// sticky tune; "1" by default.
func frameOffset(video string) string {
	b, err := os.ReadFile(ryowallsTune())
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

// liveEncRev marks the transcode flags a cached clip was produced with. Bump it
// whenever they change, so old clips are re-encoded instead of being replayed
// with settings livewall no longer expects.
const liveEncRev = "2"

// liveFps: the rate a clip is transcoded to, and so the rate livewall decodes it
// at (the daemon paces off the stream's own frame rate). 30 keeps software decode
// affordable on any machine; the Performance page's 60fps switch roughly doubles
// that cost for hardware with the headroom. A source that cannot supply 60 stays
// at 30 rather than being padded with duplicate frames livewall would decode for
// nothing.
func liveFps(pic string) string {
	if !perfFlag("liveWallpaper60") {
		return "30"
	}
	out, err := exec.Command("ffprobe", "-v", "error", "-select_streams", "v:0",
		"-show_entries", "stream=r_frame_rate", "-of", "default=nw=1:nk=1", pic).Output()
	if err != nil {
		return "30"
	}
	// r_frame_rate is a rational: "60/1", or "60000/1001" for NTSC rates.
	num, den, _ := strings.Cut(strings.TrimSpace(string(out)), "/")
	n, err := strconv.ParseFloat(num, 64)
	if err != nil {
		return "30"
	}
	d, err := strconv.ParseFloat(den, 64)
	if err != nil || d <= 0 {
		d = 1
	}
	if n/d < 50 {
		return "30"
	}
	return "60"
}

// livewallSource: the cached H.264 that livewall decodes, transcoded once per
// clip + cap width (keyed by path, mtime, cap, fps and encoder rev). Software-decoding
// the 4K source directly would blow the RAM budget; downscaling to the screen's
// width keeps livewall bounded while matching the panel, so the video is not
// upscaled to a blur. B-frames are off: they buy compression this cache does not
// need, and each one the decoder holds for reordering is a full frame of RAM
// (~3.5 MB at 2048x1152) charged against livewall's budget for the clip's life.
// "" if ffmpeg fails, so the caller keeps the clip's still frame.
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
	fps := liveFps(pic)
	out := filepath.Join(dir, name+"-"+strconv.FormatInt(st.ModTime().Unix(), 10)+"-"+capW+"-"+fps+"-r"+liveEncRev+".mp4")
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
		"-vf", "scale='min("+capW+",iw)':-2:flags=bicubic", "-r", fps,
		"-c:v", "libx264", "-preset", "veryfast", "-bf", "0", "-pix_fmt", "yuv420p", "-an", tmp).Run()
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

// scheduleTheme: nudge the palette/border worker, non-blocking. buffered channel
// coalesces a burst into the latest, so theming runs once the presses settle.
func (d *daemon) scheduleTheme() {
	select {
	case d.paintSig <- struct{}{}:
	default:
	}
}

// paintWorker: regen the palette for whatever is on screen, reload hypr
// (config-only, monitors untouched), wake the LED worker. matugenApply extracts
// the palette to ~/.cache/ryoku/colors.json (the desktop visualiser live-
// watches it, so its spectrum retunes too) and fans that one palette into every
// app config. reads state every pass, so a coalesced burst themes the final
// wallpaper. runs for the life of the daemon.
func (d *daemon) paintWorker() {
	for range d.paintSig {
		// Self-heal a stale signature before any hyprctl fork: if Hyprland
		// restarted under this persisted daemon, re-bind so the border reload
		// and the cursor recolour reach the live compositor (see hyprsig.go).
		ensureLiveHyprSignature()
		// Before deciding who owns the palette: the surfaces floating on the
		// picture need its luminance map either way, named theme or not.
		writeWallpaperTone(readState())
		// A fixed named theme owns the palette: fan its curated palette into the
		// same app templates the wallpaper path renders, then reload, so apps
		// follow the shell rail's master instead of the last wallpaper render. No
		// wallpaper is needed, so this runs before the wallpaper-file guard below.
		if staticThemeActive() {
			if name := staticThemeName(); name != "" {
				if err := d.matugenApplyStatic(name); err != nil {
					fmt.Fprintf(os.Stderr, "paintWorker matugen static: %v\n", err)
				} else {
					_ = exec.Command("hyprctl", "reload", "config-only").Run()
					select {
					case d.ledsSig <- struct{}{}:
					default:
					}
				}
			}
			continue
		}
		pic := readState()
		if pic == "" || !isFile(pic) {
			continue
		}
		// The dynamic pipeline owns the palette only while Match wallpaper is on
		// and no fixed named theme is selected; otherwise it idles so it never
		// fights the theme daemon's static palette.
		if !matugenFollows() {
			continue
		}
		// matugen reads a still image, so a video is themed off one extracted frame.
		src := pic
		if isVideo(pic) {
			if src = liveFrame(pic); src == "" {
				continue
			}
		}
		if err := d.matugenApply(src); err != nil {
			fmt.Fprintf(os.Stderr, "paintWorker matugen: %v\n", err)
		}
		_ = exec.Command("hyprctl", "reload", "config-only").Run()
		select {
		case d.ledsSig <- struct{}{}:
		default:
		}
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

// ryowallsTune: the ryowalls per-image tune (ryoku-ryowalls.json). frameOffset
// reads the sampled frame second for a video wallpaper from it.
func ryowallsTune() string { return filepath.Join(stateDir(), "ryoku-ryowalls.json") }

// ledsWorker: push the new accent at the lighting devices the user put under
// Ryoku's control. `ryoku-hub lighting accent` returns without touching anything
// while lighting is off or no device is adopted, so an untouched install never
// talks to a keyboard. Reaching hardware is slow (seconds on first use), so it
// lives on its own coalescing worker and never touches the wallpaper hot path.
// Runs for the life of the daemon.
func (d *daemon) ledsWorker() {
	for range d.ledsSig {
		_ = exec.Command(findHubBin(), "lighting", "accent").Run()
	}
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
