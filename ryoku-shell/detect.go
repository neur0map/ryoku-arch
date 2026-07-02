package main

// detect.go is the only place that inspects the machine. Everything the plan
// and the engine decide on comes from one facts struct filled in here, so a
// dry run and a real run see the same world.

import (
	"net/http"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"regexp"
	"strings"
	"syscall"
	"time"
)

type facts struct {
	distroID   string
	distroLike string
	distroName string
	archX86    bool
	pacman     bool
	archLike   bool
	online     bool
	btrfsRoot  bool

	gpus        []string
	hasNvidia   bool
	nouveauLive bool
	ucodePkg    string

	currentDM string   // enabled display-manager unit ("" = none)
	otherNet  []string // enabled network stacks other than NetworkManager
	nmEnabled bool

	aurHelper   string
	rivalPkgs   []string // conflicting shell packages installed
	blockerPkgs []string // packages that abort the pacman transaction if left
	softUnits   []string // enabled user units that fight the shell
	niriFound   bool
	kbLayout    string
	userShell   string
	ryokuOnBox  bool // ryoku-desktop already installed
	hostname    string
	username    string
	homeDir     string
	hyprCfgDirs []string // pre-existing ~/.config/{hypr,quickshell,niri}
}

// rival quickshell stacks; ordered meta -> shell -> runtime so pacman removal
// never trips its own dependency checks (iNiR's conflicts model).
var rivalShellPkgs = []string{
	"cachyos-niri-noctalia", "noctalia-shell", "noctalia-shell-git", "noctalia-qs",
	"dms-shell", "dms-shell-git", "dms-shell-greeter",
	"caelestia-shell", "caelestia-shell-git",
	"inir-shell", "inir-shell-git", "bms-shell-bin",
}

// installed packages that make `pacman -S --noconfirm` of the desktop set
// abort with an unresolved conflict (pacman answers conflict prompts with No).
var conflictBlockerPkgs = []string{
	"pulseaudio", "pulseaudio-alsa", "pulseaudio-bluetooth",
	"quickshell-git", "quickshell-bin",
}

// user daemons the Ryoku shell replaces (notifications, bar, wallpaper, idle,
// rival shell services). disabled at install, never uninstalled.
var softConflictUnits = []string{
	"dunst.service", "mako.service", "swaync.service", "fnott.service",
	"waybar.service", "polybar.service", "eww.service", "ironbar.service",
	"swww.service", "swww-daemon.service", "hyprpaper.service", "wpaperd.service",
	"swayidle.service", "swayosd.service",
	"noctalia.service", "dms.service", "inir.service", "caelestia.service",
}

var otherDMUnits = []string{
	"gdm.service", "gdm3.service", "lightdm.service", "lxdm.service",
	"greetd.service", "ly.service", "cosmic-greeter.service", "xdm.service",
}

var otherNetUnits = []string{
	"systemd-networkd.service", "dhcpcd.service", "connman.service", "netctl.service",
}

func out(name string, args ...string) string {
	b, err := exec.Command(name, args...).Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

func has(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

func pacmanHas(pkg string) bool {
	return exec.Command("pacman", "-Qq", pkg).Run() == nil
}

func unitEnabled(scope, unit string) bool {
	args := []string{"is-enabled", unit}
	if scope == "user" {
		args = append([]string{"--user"}, args...)
	}
	return out("systemctl", args...) == "enabled"
}

func parseOSRelease(text string) (id, like, name string) {
	for _, ln := range strings.Split(text, "\n") {
		k, v, ok := strings.Cut(ln, "=")
		if !ok {
			continue
		}
		v = strings.Trim(v, `"`)
		switch k {
		case "ID":
			id = v
		case "ID_LIKE":
			like = v
		case "PRETTY_NAME":
			name = v
		}
	}
	return
}

// niri config keeps xkb layout as `layout "us,de"` inside an xkb block.
var kdlLayoutRe = regexp.MustCompile(`(?m)^\s*layout\s+"([^"]+)"`)

func niriLayout(cfg string) string {
	if m := kdlLayoutRe.FindStringSubmatch(cfg); m != nil {
		return m[1]
	}
	return ""
}

var x11LayoutRe = regexp.MustCompile(`X11 Layout:\s*(\S+)`)

func detect() *facts {
	f := &facts{}

	if b, err := os.ReadFile("/etc/os-release"); err == nil {
		f.distroID, f.distroLike, f.distroName = parseOSRelease(string(b))
	}
	f.archX86 = out("uname", "-m") == "x86_64"
	f.pacman = has("pacman")
	f.archLike = f.distroID == "arch" || strings.Contains(f.distroLike, "arch")

	u, err := user.Current()
	if err == nil {
		f.username = u.Username
		f.homeDir = u.HomeDir
	}
	if f.homeDir == "" {
		f.homeDir, _ = os.UserHomeDir()
	}
	f.hostname, _ = os.Hostname()
	f.userShell = os.Getenv("SHELL")

	// repo reachability probe; the install needs the network anyway.
	client := &http.Client{Timeout: 6 * time.Second}
	if resp, err := client.Head("https://repo.ryoku.dev/stable/x86_64/ryoku.db"); err == nil {
		resp.Body.Close()
		f.online = resp.StatusCode < 500
	}

	var st syscall.Statfs_t
	if syscall.Statfs("/", &st) == nil {
		f.btrfsRoot = st.Type == 0x9123683e
	}

	f.detectGPUs()
	f.detectUcode()

	// enabled display manager: the display-manager.service alias symlink is
	// authoritative; fall back to probing the known units.
	if tgt, err := os.Readlink("/etc/systemd/system/display-manager.service"); err == nil {
		f.currentDM = filepath.Base(tgt)
	} else {
		for _, dm := range append([]string{"sddm.service"}, otherDMUnits...) {
			if unitEnabled("system", dm) {
				f.currentDM = dm
				break
			}
		}
	}

	f.nmEnabled = unitEnabled("system", "NetworkManager.service")
	for _, n := range otherNetUnits {
		if unitEnabled("system", n) {
			f.otherNet = append(f.otherNet, n)
		}
	}

	for _, h := range []string{"yay", "paru"} {
		if has(h) {
			f.aurHelper = h
			break
		}
	}

	if f.pacman {
		for _, p := range rivalShellPkgs {
			if pacmanHas(p) {
				f.rivalPkgs = append(f.rivalPkgs, p)
			}
		}
		for _, p := range conflictBlockerPkgs {
			if pacmanHas(p) {
				f.blockerPkgs = append(f.blockerPkgs, p)
			}
		}
		f.ryokuOnBox = pacmanHas("ryoku-desktop")
		f.niriFound = pacmanHas("niri")
	}
	for _, unit := range softConflictUnits {
		if unitEnabled("user", unit) {
			f.softUnits = append(f.softUnits, unit)
		}
	}

	cfg := filepath.Join(f.homeDir, ".config")
	for _, d := range []string{"hypr", "quickshell", "niri"} {
		if _, err := os.Stat(filepath.Join(cfg, d)); err == nil {
			f.hyprCfgDirs = append(f.hyprCfgDirs, d)
			if d == "niri" {
				f.niriFound = true
			}
		}
	}

	// keyboard layout: prefer the niri config the user actually lives in,
	// fall back to localectl's X11 layout.
	if b, err := os.ReadFile(filepath.Join(cfg, "niri/config.kdl")); err == nil {
		f.kbLayout = niriLayout(string(b))
	}
	if f.kbLayout == "" {
		if m := x11LayoutRe.FindStringSubmatch(out("localectl", "status")); m != nil {
			f.kbLayout = m[1]
		}
	}
	// localectl reports placeholders when nothing is configured.
	if f.kbLayout == "(unset)" || f.kbLayout == "n/a" {
		f.kbLayout = ""
	}

	return f
}

func (f *facts) detectGPUs() {
	cards, _ := filepath.Glob("/sys/class/drm/card*/device/uevent")
	seen := map[string]bool{}
	for _, c := range cards {
		b, err := os.ReadFile(c)
		if err != nil {
			continue
		}
		for _, ln := range strings.Split(string(b), "\n") {
			if drv, ok := strings.CutPrefix(ln, "DRIVER="); ok && !seen[drv] {
				seen[drv] = true
				f.gpus = append(f.gpus, drv)
			}
		}
	}
	if seen["nvidia"] || seen["nouveau"] {
		f.hasNvidia = true
	}
	// lspci catches NVIDIA cards with no driver bound at all.
	if !f.hasNvidia && has("lspci") {
		if strings.Contains(strings.ToLower(out("lspci")), "nvidia") {
			f.hasNvidia = true
		}
	}
	f.nouveauLive = seen["nouveau"]
	if b, err := os.ReadFile("/proc/modules"); err == nil {
		if strings.Contains(string(b), "nouveau ") {
			f.nouveauLive = true
		}
	}
}

func (f *facts) detectUcode() {
	b, err := os.ReadFile("/proc/cpuinfo")
	if err != nil {
		return
	}
	s := string(b)
	switch {
	case strings.Contains(s, "AuthenticAMD"):
		f.ucodePkg = "amd-ucode"
	case strings.Contains(s, "GenuineIntel"):
		f.ucodePkg = "intel-ucode"
	}
	if f.ucodePkg != "" && pacmanHas(f.ucodePkg) {
		f.ucodePkg = "" // already there, nothing to add
	}
}

func (f *facts) gpuSummary() string {
	if len(f.gpus) == 0 {
		return "none detected"
	}
	return strings.Join(f.gpus, ", ")
}

func (f *facts) otherDM() string {
	if f.currentDM != "" && f.currentDM != "sddm.service" {
		return f.currentDM
	}
	return ""
}
