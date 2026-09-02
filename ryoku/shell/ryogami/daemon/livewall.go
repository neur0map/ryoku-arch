package main

// The ryoku-livewall pipeline: a video wallpaper plays through the in-repo C
// player (ryoku/shell/livewall), which software-decodes a pre-transcoded clip
// into wl_shm buffers on a wlr background surface. It maps no GPU/EGL driver,
// so it holds ~40-60 MB RSS on any vendor, where mpv/mpvpaper (a client GL
// pipeline) cost 300-700 MB, leak per loop, and on a hybrid layout dropped
// frames wholesale. The daemon transcodes each clip once to the panel's
// logical width (VAAPI when an AMD node is present, ~2s for a 4K clip; libx264
// otherwise) and caches it, so the player's steady cost is a fraction of a core.

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

const liveDaemon = "ryogami-live"

// liveEncRev marks the transcode flags a cached clip was produced with. Bump it
// whenever they change, so old clips are re-encoded instead of being replayed
// with settings livewall no longer expects.
const liveEncRev = "4"

// liveCapWidth caps the player's decode/render width at the widest monitor's
// PHYSICAL pixel width, so a video wallpaper renders 1:1 with the panel. The
// compositor upscales the buffer to physical pixels, so encoding at the
// logical width (physical / fractional scale, an earlier bug) came out soft on
// any scaled monitor: 1920 @ 1.25 cached at 1536 and stretched back up. The
// ceiling bounds software decode and the player's RSS by resource tier; a
// wider panel plays at the ceiling rather than blow the budget. 1920 when
// hyprctl is absent.
func liveCapWidth(tier string) int {
	floor, ceil := 1280, 2560
	switch tier {
	case "low":
		ceil = 1920
	case "high":
		ceil = 3840
	}
	best := 1920
	if out, err := exec.Command("hyprctl", "monitors", "-j").Output(); err == nil {
		var mons []struct {
			Width int `json:"width"`
		}
		if json.Unmarshal(out, &mons) == nil {
			w := 0
			for _, m := range mons {
				if m.Width > w {
					w = m.Width
				}
			}
			if w > 0 {
				best = w
			}
		}
	}
	if best < floor {
		best = floor
	}
	if best > ceil {
		best = ceil
	}
	return best
}

// liveProbe reads the one video stream's shape in a single ffprobe call.
// Zero-value fields on failure: callers fall back to transcoding.
type liveShape struct {
	codec  string
	pixFmt string
	width  int
	fps    float64
}

func liveProbe(path string) liveShape {
	out, err := exec.Command("ffprobe", "-v", "error", "-select_streams", "v:0",
		"-show_entries", "stream=codec_name,pix_fmt,width,r_frame_rate",
		"-of", "default=nw=1", path).Output()
	var s liveShape
	if err != nil {
		return s
	}
	for _, line := range strings.Split(string(out), "\n") {
		k, v, ok := strings.Cut(strings.TrimSpace(line), "=")
		if !ok {
			continue
		}
		switch k {
		case "codec_name":
			s.codec = v
		case "pix_fmt":
			s.pixFmt = v
		case "width":
			s.width, _ = strconv.Atoi(v)
		case "r_frame_rate":
			num, den, _ := strings.Cut(v, "/")
			n, errN := strconv.ParseFloat(num, 64)
			d, errD := strconv.ParseFloat(den, 64)
			if errN == nil && errD == nil && d > 0 {
				s.fps = n / d
			}
		}
	}
	return s
}

// liveFps is the rate a clip is transcoded to, and so the rate the player
// decodes it at (it paces off the stream's own frame rate). The source rate is
// kept, only capped by tier: padding a 24fps clip to 30 would duplicate frames
// into judder, and downsampling to below the cap loses nothing but decode
// cost. An unreadable rate falls back to 30.
func liveFps(tier string, src liveShape) string {
	ceil := 30.0
	switch tier {
	case "low":
		ceil = 24
	case "high":
		ceil = 60
	}
	fps := src.fps
	if fps <= 0 {
		fps = 30
	}
	if fps > ceil {
		fps = ceil
	}
	if fps < 1 {
		fps = 1
	}
	return strconv.Itoa(int(fps + 0.5))
}

// liveDirect reports whether livewall can decode the source as-is: already
// H.264 8-bit within the width and rate budget, so a transcode would only
// re-encode what the player affords anyway.
func liveDirect(src liveShape, capW int, fps string) bool {
	target, _ := strconv.ParseFloat(fps, 64)
	return src.codec == "h264" && src.pixFmt == "yuv420p" &&
		src.width > 0 && src.width <= capW &&
		src.fps > 0 && src.fps <= target+6
}

// livewallSource is the cached clip livewall decodes, transcoded once per clip,
// cap width, rate and encoder rev (keyed by mtime, so an edited file re-encodes).
// VAAPI on an AMD render node does the whole decode-scale-encode on the video
// engine; without one, libx264 with bicubic scaling. B-frames are off: they buy
// compression this cache does not need, and each one the decoder holds for
// reordering is a full frame of RAM charged against livewall's budget.
// "" if every encoder fails, so the caller keeps the clip's still frame.
func livewallSource(pic string, src liveShape, capW int, fps string) string {
	st, err := os.Stat(pic)
	if err != nil {
		return ""
	}
	if liveDirect(src, capW, fps) {
		return pic
	}
	dir := livewallCacheDir()
	name := strings.TrimSuffix(filepath.Base(pic), filepath.Ext(pic))
	cap := strconv.Itoa(capW)
	out := filepath.Join(dir, name+"-"+strconv.FormatInt(st.ModTime().Unix(), 10)+"-"+cap+"-"+fps+"-r"+liveEncRev+".mp4")
	if fileExists(out) {
		return out
	}
	if os.MkdirAll(dir, 0o755) != nil {
		return ""
	}
	// pid-unique tmp: two rapid sets of the same clip transcode concurrently
	// (the generation guard drops the launch, not the encode); a shared tmp
	// would interleave both writers into a corrupt cached video.
	tmp := out + ".tmp." + strconv.Itoa(os.Getpid()) + "-" + strconv.FormatInt(time.Now().UnixNano(), 10) + ".mp4"
	if !runTranscode(pic, tmp, src, capW, fps) {
		_ = os.Remove(tmp)
		return ""
	}
	if os.Rename(tmp, out) != nil {
		_ = os.Remove(tmp)
		return ""
	}
	return out
}

func runTranscode(pic, tmp string, src liveShape, capW int, fps string) bool {
	if dev := vaapiRenderNode(); dev != "" {
		w := capW
		if src.width > 0 && src.width < w {
			w = src.width
		}
		w &^= 1
		err := exec.Command("ffmpeg", "-y", "-v", "error",
			"-hwaccel", "vaapi", "-hwaccel_device", dev, "-hwaccel_output_format", "vaapi",
			"-i", pic,
			"-vf", "fps="+fps+",scale_vaapi=w="+strconv.Itoa(w)+":h=-2:format=nv12",
			"-c:v", "h264_vaapi", "-qp", "20", "-bf", "0", "-an", tmp).Run()
		if err == nil && fileExists(tmp) {
			return true
		}
		_ = os.Remove(tmp)
	}
	// The CPU fallback runs niced with bounded threads: a background encode
	// must never contend with the desktop.
	err := exec.Command("nice", "-n", "19", "ffmpeg", "-y", "-v", "error", "-i", pic,
		"-vf", "scale='min("+strconv.Itoa(capW)+",iw)':-2:flags=bicubic", "-r", fps,
		"-c:v", "libx264", "-preset", "veryfast", "-crf", "18", "-bf", "0",
		"-threads", "4", "-pix_fmt", "yuv420p", "-an", tmp).Run()
	return err == nil && fileExists(tmp)
}

// liveStill extracts one full-resolution frame from a clip, cached per mtime.
// The shell paints it as the frame under the player: the reveal transition, the
// depth cutout and the palette all read this still, and it holds the screen
// through the one-time transcode and if the player ever dies. "" on failure.
func liveStill(video string, sec float64) string {
	st, err := os.Stat(video)
	if err != nil {
		return ""
	}
	if sec <= 0 {
		sec = 1
	}
	secStr := strconv.FormatFloat(sec, 'f', 1, 64)
	dir := livewallCacheDir()
	name := strings.TrimSuffix(filepath.Base(video), filepath.Ext(video))
	out := filepath.Join(dir, name+"-"+strconv.FormatInt(st.ModTime().Unix(), 10)+"-still-"+secStr+".jpg")
	if fileExists(out) {
		return out
	}
	if os.MkdirAll(dir, 0o755) != nil {
		return ""
	}
	tmp := out + ".tmp." + strconv.Itoa(os.Getpid()) + ".jpg"
	err = exec.Command("ffmpeg", "-y", "-v", "error", "-ss", secStr, "-i", video,
		"-frames:v", "1", "-q:v", "2", tmp).Run()
	if err != nil || !fileExists(tmp) {
		// Clips shorter than a second: take the first frame instead.
		err = exec.Command("ffmpeg", "-y", "-v", "error", "-i", video,
			"-frames:v", "1", "-q:v", "2", tmp).Run()
		if err != nil || !fileExists(tmp) {
			_ = os.Remove(tmp)
			return ""
		}
	}
	if os.Rename(tmp, out) != nil {
		_ = os.Remove(tmp)
		return ""
	}
	return out
}

// cacheHome resolves XDG_CACHE_HOME with the ~/.cache fallback.
func cacheHome() string {
	if base := os.Getenv("XDG_CACHE_HOME"); base != "" {
		return base
	}
	return filepath.Join(os.Getenv("HOME"), ".cache")
}

// liveFit maps the shell's contentFit vocabulary onto livewall's argv: "fit"
// letterboxes the whole clip (Contain), anything else covers the screen.
func liveFit(contentFit string) string {
	if contentFit == "Contain" {
		return "fit"
	}
	return "fill"
}

// vaapiRenderNode is the AMD render node the transcode runs on, "" when the
// machine has no amdgpu card or no radeonsi backend: with a hybrid layout the
// default libva probe walks into the NVIDIA shim, which cannot encode.
func vaapiRenderNode() string {
	if !fileExists("/usr/lib/dri/radeonsi_drv_video.so") {
		return ""
	}
	nodes, _ := filepath.Glob("/sys/class/drm/renderD*/device/driver")
	for _, n := range nodes {
		if dst, err := os.Readlink(n); err == nil && filepath.Base(dst) == "amdgpu" {
			return "/dev/dri/" + filepath.Base(filepath.Dir(filepath.Dir(n)))
		}
	}
	return ""
}

// transcodeCachePath is the cached re-encode path for a clip at a given
// fps/width cap, keyed by source mtime + cap (distinct from livewallSource).
func transcodeCachePath(src string, fps, capW int) string {
	st, err := os.Stat(src)
	if err != nil {
		return ""
	}
	dir := filepath.Join(cacheHome(), "ryogami", "livewall")
	name := strings.TrimSuffix(filepath.Base(src), filepath.Ext(src))
	return filepath.Join(dir, name+"-"+strconv.FormatInt(st.ModTime().Unix(), 10)+
		"-w"+strconv.Itoa(capW)+"-f"+strconv.Itoa(fps)+".mp4")
}

// ensureVideoTranscode re-encodes a clip to a bite-sized mp4 (fps + width
// capped), cached per source mtime and cap, for the in-shell engine. "" on
// failure keeps the original.
func ensureVideoTranscode(src string, fps, capW int) string {
	out := transcodeCachePath(src, fps, capW)
	if out == "" {
		return ""
	}
	if fileExists(out) {
		return out
	}
	if os.MkdirAll(filepath.Dir(out), 0o755) != nil {
		return ""
	}
	tmp := out + ".tmp." + strconv.Itoa(os.Getpid()) + "-" + strconv.FormatInt(time.Now().UnixNano(), 10) + ".mp4"
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Minute)
	defer cancel()
	cmd := exec.CommandContext(ctx, "nice", "-n", "19", "ffmpeg", "-y", "-v", "error",
		"-i", src,
		"-vf", fmt.Sprintf("scale='min(%d,iw)':-2:flags=bicubic,fps=%d", capW, fps),
		"-c:v", "libx264", "-preset", "veryfast", "-crf", "23", "-bf", "0",
		"-pix_fmt", "yuv420p", "-an", tmp)
	if err := cmd.Run(); err != nil || !fileExists(tmp) {
		_ = os.Remove(tmp)
		return ""
	}
	if os.Rename(tmp, out) != nil {
		_ = os.Remove(tmp)
		return ""
	}
	return out
}
