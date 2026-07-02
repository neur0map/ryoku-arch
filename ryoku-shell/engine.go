package main

// engine.go runs the install: ordered steps, each an idempotent shell-out
// sequence streamed line by line to the UI and the log file. The recipe is
// installation/backend/lib/deploy.sh translated from chroot to live system,
// plus the migration work (backup, rival shells, DM/network switch) that an
// existing machine needs and a blank ISO target never did.

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"
)

// line-anchored so a commented-out "#[ryoku]" stanza does not count.
var ryokuStanzaRe = regexp.MustCompile(`(?m)^\[ryoku\]`)

const repoURL = "https://github.com/neur0map/ryoku-arch.git"

const pacmanStanza = `
[ryoku]
SigLevel = Required
Server = https://repo.ryoku.dev/stable/$arch
`

// desktop set from deploy.sh plus the session/system packages the ISO puts in
// base.packages that ryoku-desktop does not depend on. --needed makes overlap
// free.
var ryokuPkgs = []string{"ryoku-keyring", "ryoku-shell", "ryoku-hub", "ryoku-blobs", "ryoku", "ryoku-desktop"}

var sessionPkgs = []string{
	"sddm", "networkmanager", "iwd", "iw",
	"pipewire", "pipewire-alsa", "pipewire-pulse", "wireplumber",
	"mesa", "vulkan-icd-loader",
	"xdg-user-dirs", "qt6ct", "adwaita-icon-theme", "vimix-cursors",
	"polkit", "gnome-keyring",
	"qt6-declarative", "qt6-multimedia", "qt6-multimedia-ffmpeg",
	"gst-plugins-base", "gst-plugins-good", "gst-plugins-bad", "gst-plugins-ugly",
	"upower", "fuzzel", "curl", "libnotify", "python", "xdg-utils", "desktop-file-utils",
	// tools the shell invokes by name (stash, launcher, media, night light)
	"flatpak", "ffmpeg", "yt-dlp", "mpv", "libqalculate", "mpv-mpris", "songrec",
}

// wallust and awww-git are the shell's wallpaper/palette engine; the rest are
// the standard Ryoku extras. all best-effort, verify flags the critical two.
var aurPkgs = []string{"wallust", "awww-git", "bibata-cursor-theme-bin", "localsend-bin", "handy-bin"}

var sparsePaths = []string{
	"ryoku/lockscreen", "ryoku/assets", "ryoku/apps",
	"system/hardware/drivers", "release/packages/ryoku-keyring",
}

type plan struct {
	nvidia    bool // proprietary NVIDIA driver setup
	switchDM  bool // disable current DM, enable SDDM
	switchNet bool // disable other network stacks, enable NetworkManager
	rivals    bool // remove rival shell packages
	softOff   bool // disable conflicting user daemons
	aur       bool // AUR extras
	fish      bool // fish as login shell
}

func defaultPlan(f *facts) *plan {
	return &plan{
		nvidia:    f.hasNvidia && !f.nouveauLive,
		switchDM:  true,
		switchNet: true,
		rivals:    true,
		softOff:   true,
		aur:       true,
		fish:      !strings.HasSuffix(f.userShell, "/fish"),
	}
}

type evStep struct {
	idx   int
	title string
}
type evLine struct{ line string }
type evDone struct {
	err error
	idx int
}

type estep struct {
	id    string
	title string
	fn    func(*engine) error
}

type engine struct {
	f   *facts
	p   *plan
	dry bool
	ref string

	events  chan any
	logf    *os.File
	logPath string
	logMu   sync.Mutex

	payloadOverride string
	payload         string
	backupDir       string
	restorePath     string
	prevBackups     int

	steps []estep
}

func newEngine(f *facts, p *plan, dry bool, ref, payloadOverride string) *engine {
	e := &engine{f: f, p: p, dry: dry, ref: ref, payloadOverride: payloadOverride}
	e.openLog()
	// repo trust comes before conflict removal on purpose: nothing gets
	// uninstalled until the [ryoku] db has actually been fetched.
	e.steps = []estep{
		{"sysupgrade", "Updating the system (pacman -Syu)", stepSysupgrade},
		{"tools", "Installing installer tools (git, base-devel)", stepTools},
		{"payload", "Fetching the Ryoku payload", stepPayload},
		{"backup", "Backing up your configs", stepBackup},
		{"repo", "Trusting the [ryoku] package repository", stepRepo},
		{"conflicts", "Clearing conflicting shells and daemons", stepConflicts},
		{"packages", "Installing the Ryoku desktop", stepPackages},
		{"drivers", "Setting up GPU drivers", stepDrivers},
		{"session", "Wiring the login session (SDDM, network)", stepSession},
		{"configs", "Laying down your Ryoku configs", stepConfigs},
		{"aur", "Building the AUR extras", stepAUR},
		{"shell", "Switching your login shell to fish", stepFish},
		{"doctor", "Converging the system (ryoku doctor)", stepDoctor},
		{"verify", "Verifying the install", stepVerify},
	}
	return e
}

func (e *engine) openLog() {
	// dry runs must not touch the filesystem beyond a throwaway log.
	dir := os.TempDir()
	if !e.dry {
		dir = filepath.Join(e.f.homeDir, ".local/state/ryoku")
		if err := os.MkdirAll(dir, 0o755); err != nil {
			dir = os.TempDir()
		}
	}
	e.logPath = filepath.Join(dir, "shell-install.log")
	e.logf, _ = os.OpenFile(e.logPath, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	e.log(fmt.Sprintf("---- ryoku-shell-install run %s (dry=%v ref=%s) ----", time.Now().Format(time.RFC3339), e.dry, e.ref))
}

func (e *engine) log(s string) {
	e.logMu.Lock()
	defer e.logMu.Unlock()
	if e.logf != nil {
		fmt.Fprintln(e.logf, s)
	}
}

func (e *engine) say(s string) {
	e.log(s)
	if e.events != nil {
		e.events <- evLine{line: s}
	}
}

func (e *engine) sayf(format string, a ...any) { e.say(fmt.Sprintf(format, a...)) }

// runFrom executes steps starting at idx (retry re-enters at the failed one).
func (e *engine) runFrom(idx int) chan any {
	e.events = make(chan any, 256)
	go func() {
		for i := idx; i < len(e.steps); i++ {
			s := e.steps[i]
			e.events <- evStep{idx: i, title: s.title}
			e.log("==== step " + s.id + " ====")
			if err := s.fn(e); err != nil {
				e.sayf("step %s failed: %v", s.id, err)
				e.events <- evDone{err: err, idx: i}
				return
			}
		}
		e.events <- evDone{idx: len(e.steps)}
	}()
	return e.events
}

func shellJoin(name string, args []string) string {
	parts := []string{name}
	for _, a := range args {
		if strings.ContainsAny(a, " \t\"'$") {
			a = fmt.Sprintf("%q", a)
		}
		parts = append(parts, a)
	}
	return strings.Join(parts, " ")
}

// cmd runs a command streaming merged stdout/stderr into the UI and the log.
func (e *engine) cmd(dir string, env []string, name string, args ...string) error {
	line := shellJoin(name, args)
	if e.dry {
		e.say("DRYRUN: " + line)
		return nil
	}
	e.say("$ " + line)
	c := exec.Command(name, args...)
	c.Dir = dir
	if len(env) > 0 {
		c.Env = append(os.Environ(), env...)
	}
	pr, pw := io.Pipe()
	c.Stdout, c.Stderr = pw, pw
	var wg sync.WaitGroup
	wg.Add(1)
	go func() {
		defer wg.Done()
		// ReadString instead of a Scanner: a Scanner stops at its buffer cap
		// and the write side of the pipe then blocks forever.
		rd := bufio.NewReader(pr)
		for {
			ln, err := rd.ReadString('\n')
			if ln = strings.TrimRight(ln, "\r\n"); ln != "" {
				e.say("  " + ln)
			}
			if err != nil {
				return
			}
		}
	}()
	err := c.Run()
	pw.Close()
	wg.Wait()
	if err != nil {
		return fmt.Errorf("%s: %w", name, err)
	}
	return nil
}

func (e *engine) sudo(args ...string) error {
	return e.cmd("", nil, "sudo", append([]string{"-n"}, args...)...)
}

// sudoSh runs a fixed shell snippet as root; only static strings go in here.
func (e *engine) sudoSh(script string) error {
	return e.cmd("", nil, "sudo", "-n", "sh", "-c", script)
}

// ---- steps ----

func stepSysupgrade(e *engine) error {
	return e.sudo("pacman", "-Syu", "--noconfirm")
}

func stepTools(e *engine) error {
	return e.sudo("pacman", "-S", "--needed", "--noconfirm", "git", "base-devel")
}

func stepPayload(e *engine) error {
	if e.payloadOverride != "" {
		e.payload = e.payloadOverride
		if _, err := os.Stat(filepath.Join(e.payload, "ryoku/lockscreen/install-qylock")); err != nil && !e.dry {
			return fmt.Errorf("payload override %s does not look like a ryoku-arch checkout", e.payload)
		}
		e.say("using payload checkout " + e.payload)
		return nil
	}
	cache := os.Getenv("XDG_CACHE_HOME")
	if cache == "" {
		cache = filepath.Join(e.f.homeDir, ".cache")
	}
	e.payload = filepath.Join(cache, "ryoku-shell-install/repo")

	if _, err := os.Stat(filepath.Join(e.payload, ".git")); err == nil {
		if err := e.cmd(e.payload, nil, "git", "fetch", "--depth=1", "origin", e.ref); err != nil {
			return err
		}
		if err := e.cmd(e.payload, nil, "git", "checkout", "-f", "FETCH_HEAD"); err != nil {
			return err
		}
	} else {
		if !e.dry {
			if err := os.MkdirAll(filepath.Dir(e.payload), 0o755); err != nil {
				return err
			}
		}
		if err := e.cmd("", nil, "git", "clone", "--depth=1", "--filter=blob:none", "--sparse",
			"--branch", e.ref, repoURL, e.payload); err != nil {
			return err
		}
	}
	return e.cmd(e.payload, nil, "git", append([]string{"sparse-checkout", "set"}, sparsePaths...)...)
}

// paths under $HOME that materialize or the seeds will touch. hypr, quickshell
// and the lockscreen dirs are moved aside wholesale: a stale hyprland.conf or a
// foreign quickshell tree next to the Ryoku one is exactly the breakage a
// migration must avoid. the rest are copied, then clobbered in place.
var backupMove = []string{".config/hypr", ".config/quickshell", ".local/share/quickshell-lockscreen", ".local/share/qylock"}
var backupCopy = []string{
	".config/niri", ".config/kitty", ".config/fish", ".config/nvim",
	".config/fastfetch", ".config/yazi", ".config/wallust", ".config/kdeglobals",
	".config/starship.toml", ".config/mimeapps.list",
}

func stepBackup(e *engine) error {
	root := filepath.Join(e.f.homeDir, ".local/state/ryoku/shell-install")
	if prev, _ := filepath.Glob(filepath.Join(root, "backup-*")); len(prev) > 0 {
		e.prevBackups = len(prev)
		e.say(fmt.Sprintf("note: %d earlier backup(s) exist under %s; the oldest holds your pre-Ryoku configs", len(prev), root))
	}
	if e.dry {
		e.say("DRYRUN: back up " + strings.Join(append(append([]string{}, backupMove...), backupCopy...), ", "))
		return nil
	}
	// a retry in the same run reuses the dir: items already saved are skipped
	// instead of being re-captured into a second, half-empty backup.
	if e.backupDir == "" {
		e.backupDir = filepath.Join(root, "backup-"+time.Now().Format("20060102-150405"))
	}
	e.restorePath = filepath.Join(e.backupDir, "restore.sh")
	if err := os.MkdirAll(e.backupDir, 0o755); err != nil {
		return err
	}
	// restore.sh exists before the first item moves, and grows a line per
	// saved item, so a kill at any point leaves a script that undoes exactly
	// what happened so far.
	if _, err := os.Stat(e.restorePath); err != nil {
		hdr := "#!/usr/bin/env bash\n" +
			"# restore configs saved by ryoku-shell-install. undo lines are appended as\n" +
			"# the installer changes things; run the whole script to roll back.\n" +
			"set -euo pipefail\nDIR=\"$(cd \"$(dirname \"$0\")\" && pwd)\"\n"
		if err := os.WriteFile(e.restorePath, []byte(hdr), 0o755); err != nil {
			return err
		}
	}
	saveOne := func(rel string, move bool) error {
		src := filepath.Join(e.f.homeDir, rel)
		dst := filepath.Join(e.backupDir, rel)
		if _, err := os.Lstat(dst); err == nil {
			return nil // already saved by a previous attempt of this run
		}
		if _, err := os.Lstat(src); err != nil {
			return nil
		}
		if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
			return err
		}
		if move {
			if err := os.Rename(src, dst); err != nil {
				// cross-device home layouts (bind mounts, separate subvolume
				// mounts): fall back to copy + delete.
				if err := copyTree(src, dst); err != nil {
					return err
				}
				if err := os.RemoveAll(src); err != nil {
					return err
				}
			}
			e.say("moved aside " + rel)
		} else {
			if err := copyTree(src, dst); err != nil {
				return err
			}
			e.say("backed up " + rel)
		}
		e.recordRestore(fmt.Sprintf("rm -rf %q && mkdir -p %q && cp -a %q %q",
			"$HOME/"+rel, filepath.Dir("$HOME/"+rel), "$DIR/"+rel, "$HOME/"+rel))
		return nil
	}
	for _, rel := range backupMove {
		if err := saveOne(rel, true); err != nil {
			return err
		}
	}
	for _, rel := range backupCopy {
		if err := saveOne(rel, false); err != nil {
			return err
		}
	}
	e.say("backup at " + e.backupDir + " (restore.sh inside)")
	return nil
}

// recordRestore appends an undo line to restore.sh.
func (e *engine) recordRestore(line string) {
	if e.dry || e.restorePath == "" {
		return
	}
	fh, err := os.OpenFile(e.restorePath, os.O_APPEND|os.O_WRONLY, 0o755)
	if err != nil {
		return
	}
	defer fh.Close()
	fmt.Fprintln(fh, line)
}

func stepConflicts(e *engine) error {
	if e.p.rivals && len(e.f.rivalPkgs) > 0 {
		// plain -R, no -ns cascade: -Rns on a meta like cachyos-niri-noctalia
		// would drag niri itself out, and the plan promises niri survives as a
		// fallback session. leftover deps become orphans doctor can report.
		e.say("removing rival shell packages: " + strings.Join(e.f.rivalPkgs, " "))
		if err := e.sudo(append([]string{"pacman", "-R", "--noconfirm"}, e.f.rivalPkgs...)...); err != nil {
			e.say("bulk removal failed, retrying one by one")
			for _, p := range e.f.rivalPkgs {
				if err := e.sudo("pacman", "-R", "--noconfirm", p); err != nil {
					e.say("warning: could not remove " + p + " (continuing)")
				}
			}
		}
	}
	if len(e.f.blockerPkgs) > 0 {
		// pacman --noconfirm answers conflict prompts with No and aborts, so
		// packages that conflict with the desktop set (pulseaudio vs
		// pipewire-pulse, quickshell-git vs quickshell) must go first.
		e.say("removing packages that block the desktop install: " + strings.Join(e.f.blockerPkgs, " "))
		if err := e.sudo(append([]string{"pacman", "-R", "--noconfirm"}, e.f.blockerPkgs...)...); err != nil {
			for _, p := range e.f.blockerPkgs {
				if err := e.sudo("pacman", "-R", "--noconfirm", p); err != nil {
					e.say("warning: could not remove " + p + "; the package step may abort on a conflict")
				}
			}
		}
	}
	if e.p.softOff {
		for _, u := range e.f.softUnits {
			// disable only: killing the user's current session daemons out from
			// under them mid-install helps nobody. they end with the old session.
			if err := e.cmd("", nil, "systemctl", "--user", "disable", u); err != nil {
				e.say("warning: could not disable " + u)
				continue
			}
			e.recordRestore("systemctl --user enable " + u)
		}
	}
	return nil
}

func stepRepo(e *engine) error {
	// on a box that already has ryoku-keyring, the keyring files under
	// /usr/share/pacman/keyrings are package-owned: seeding and deleting them
	// again would strip files out of the installed package. the trustdb is
	// already populated, so the whole dance is unnecessary.
	if !e.dry && pacmanHas("ryoku-keyring") {
		e.say("ryoku-keyring already installed, key trust in place")
	} else {
		kdir := filepath.Join(e.payload, "release/packages/ryoku-keyring")
		kd := "/usr/share/pacman/keyrings"
		for _, f := range []string{"ryoku.gpg", "ryoku-trusted", "ryoku-revoked"} {
			if err := e.sudo("install", "-Dm644", filepath.Join(kdir, f), filepath.Join(kd, f)); err != nil {
				return err
			}
		}
		if err := e.sudo("pacman-key", "--populate", "ryoku"); err != nil {
			return err
		}
		// drop the seeds so the ryoku-keyring package installs without a file
		// conflict; the trustdb keeps the key (same dance as deploy.sh).
		if err := e.sudo("rm", "-f", kd+"/ryoku.gpg", kd+"/ryoku-trusted", kd+"/ryoku-revoked"); err != nil {
			return err
		}
	}

	conf, err := os.ReadFile("/etc/pacman.conf")
	if err != nil {
		return err
	}
	if !ryokuStanzaRe.Match(conf) {
		if err := e.sudoSh(`printf '%s' '` + pacmanStanza + `' >> /etc/pacman.conf`); err != nil {
			return err
		}
		e.say("added the [ryoku] repository to /etc/pacman.conf")
	} else {
		e.say("[ryoku] repository already present in /etc/pacman.conf")
	}
	// refresh right after the -Syu step, so this cannot strand a partial
	// upgrade; it only pulls the fresh [ryoku] db.
	return e.sudo("pacman", "-Sy")
}

func stepPackages(e *engine) error {
	pkgs := append(append([]string{}, ryokuPkgs...), sessionPkgs...)
	if e.f.ucodePkg != "" {
		pkgs = append(pkgs, e.f.ucodePkg)
	}
	return e.sudo(append([]string{"pacman", "-S", "--needed", "--noconfirm"}, pkgs...)...)
}

func stepDrivers(e *engine) error {
	drv := filepath.Join(e.payload, "system/hardware/drivers")
	scripts := []string{"amd.sh", "intel.sh", "vulkan.sh"}
	if e.p.nvidia {
		scripts = append(scripts, "nvidia.sh")
	} else if e.f.hasNvidia {
		e.say("skipping the NVIDIA driver setup (kept nouveau; re-run with the toggle on to switch)")
	}
	for _, s := range scripts {
		if err := e.cmd("", nil, "bash", filepath.Join(drv, s)); err != nil {
			return err
		}
	}
	if e.p.nvidia && e.f.hasNvidia {
		// the scripts install modules but leave the initramfs to the caller.
		if has("limine-mkinitcpio") {
			return e.sudo("limine-mkinitcpio")
		}
		return e.sudo("mkinitcpio", "-P")
	}
	return nil
}

func stepSession(e *engine) error {
	if e.p.switchDM {
		if dm := e.f.otherDM(); dm != "" {
			// disable, never mask or uninstall: reversible, and the running
			// greeter session is untouched until reboot.
			if err := e.sudo("systemctl", "disable", dm); err != nil {
				return err
			}
			e.recordRestore("sudo systemctl disable sddm.service && sudo systemctl enable " + dm)
		} else if e.f.currentDM == "" {
			e.recordRestore("sudo systemctl disable sddm.service && sudo systemctl set-default multi-user.target")
		}
		if err := e.cmd("", nil, "bash", filepath.Join(e.payload, "ryoku/lockscreen/sddm/setup")); err != nil {
			return err
		}
	} else {
		e.say("keeping your current display manager; select the Hyprland session at login")
	}

	// qylock bundle lives at the same system path the ISO uses, then its own
	// installer wires greeter theme + user lockscreen.
	if err := e.sudo("mkdir", "-p", "/usr/share/ryoku"); err != nil {
		return err
	}
	if err := e.sudoSh(`rm -rf /usr/share/ryoku/qylock`); err != nil {
		return err
	}
	if err := e.sudo("cp", "-r", filepath.Join(e.payload, "ryoku/lockscreen/qylock"), "/usr/share/ryoku/qylock"); err != nil {
		return err
	}
	if err := e.cmd("", []string{"RYOKU_QYLOCK_BUNDLE=/usr/share/ryoku/qylock"},
		"bash", filepath.Join(e.payload, "ryoku/lockscreen/install-qylock")); err != nil {
		return err
	}

	if e.p.switchNet {
		for _, n := range e.f.otherNet {
			if err := e.sudo("systemctl", "disable", n); err != nil {
				e.say("warning: could not disable " + n)
				continue
			}
			e.recordRestore("sudo systemctl enable " + n)
		}
		if !e.f.nmEnabled {
			if err := e.sudo("systemctl", "enable", "NetworkManager.service"); err != nil {
				return err
			}
			e.recordRestore("sudo systemctl disable NetworkManager.service")
		}
		// iwd backend pin, Ryoku network policy. takes effect at the next NM
		// restart (reboot), so the live wifi connection is never dropped.
		if err := e.sudoSh(`install -Dm644 /dev/stdin /etc/NetworkManager/conf.d/wifi-backend.conf <<'EOF'
[device]
wifi.backend=iwd
EOF`); err != nil {
			return err
		}
	} else {
		e.say("keeping your current network stack")
	}
	return nil
}

func stepConfigs(e *engine) error {
	if !e.dry {
		if _, err := os.Stat("/usr/bin/ryoku"); err != nil {
			return fmt.Errorf("the ryoku CLI is missing; the package step did not finish")
		}
	}
	if err := e.cmd("", nil, "ryoku", "materialize"); err != nil {
		return err
	}

	// keyboard layout salvaged from the machine (niri config or localectl);
	// keyboard.lua is user-owned, materialize never touches it again.
	if e.f.kbLayout != "" && e.f.kbLayout != "us" {
		e.sayf("seeding keyboard layout %q into hypr/keyboard.lua", e.f.kbLayout)
		if !e.dry {
			kb := filepath.Join(e.f.homeDir, ".config/hypr/keyboard.lua")
			content := "-- keyboard layout. user-owned: seeded by the installer from your previous\n" +
				"-- setup, then never touched by a ryoku update, so edits here stick.\n" +
				"hl.config({\n    input = {\n        kb_layout = \"" + e.f.kbLayout + "\",\n" +
				"        kb_variant = \"\",\n        kb_options = \"\",\n    },\n})\n"
			if err := os.WriteFile(kb, []byte(content), 0o644); err != nil {
				return err
			}
		}
	}

	seeds := []struct {
		src, dst string
		dir      bool
		ifAbsent bool
	}{
		{"ryoku/assets/brand", ".local/share/ryoku/assets/brand", true, false},
		{"ryoku/assets/wallpapers", "Pictures/Wallpapers", true, true},
		{"ryoku/apps/npm/npmrc", ".npmrc", false, true},
		{"ryoku/apps/nvim/ryoku-nvim.desktop", ".local/share/applications/ryoku-nvim.desktop", false, false},
		{"ryoku/apps/mimeapps.list", ".config/mimeapps.list", false, true},
	}
	for _, s := range seeds {
		src := filepath.Join(e.payload, s.src)
		dst := filepath.Join(e.f.homeDir, s.dst)
		if e.dry {
			e.say("DRYRUN: seed " + s.src + " -> ~/" + s.dst)
			continue
		}
		if err := seedPath(src, dst, s.dir, s.ifAbsent); err != nil {
			return fmt.Errorf("seed %s: %w", s.dst, err)
		}
		e.say("seeded ~/" + s.dst)
	}
	return e.cmd("", nil, "systemctl", "--user", "daemon-reload")
}

func stepAUR(e *engine) error {
	if !e.p.aur {
		e.say("AUR extras skipped by choice; wallpaper needs wallust + awww (ryoku doctor will nag)")
		return nil
	}
	helper := e.f.aurHelper
	if helper == "" {
		e.say("no AUR helper found, bootstrapping yay-bin")
		tmp, err := os.MkdirTemp("", "ryoku-yay-")
		if err != nil {
			return err
		}
		defer os.RemoveAll(tmp)
		if err := e.cmd(tmp, nil, "git", "clone", "https://aur.archlinux.org/yay-bin.git"); err != nil {
			return err
		}
		if err := e.cmd(filepath.Join(tmp, "yay-bin"), nil, "makepkg", "-si", "--noconfirm"); err != nil {
			return err
		}
		helper = "yay"
	}
	var failed []string
	for _, p := range aurPkgs {
		if err := e.cmd("", nil, helper, "-S", "--needed", "--noconfirm", p); err != nil {
			failed = append(failed, p)
			e.say("warning: AUR build failed for " + p + " (continuing)")
		}
	}
	if len(failed) > 0 {
		e.say("AUR packages that did not install: " + strings.Join(failed, " "))
		e.say("re-run later with: " + helper + " -S " + strings.Join(failed, " "))
	}
	return nil
}

func stepFish(e *engine) error {
	if !e.p.fish {
		e.say("keeping your current login shell")
		return nil
	}
	if err := e.sudo("usermod", "-s", "/usr/bin/fish", e.f.username); err != nil {
		return err
	}
	e.recordRestore("sudo usermod -s " + e.f.userShell + " " + e.f.username)
	return nil
}

func stepDoctor(e *engine) error {
	// doctor converges snapper (btrfs only), NVIDIA modeset, greeter perms,
	// session components. findings are advice, not failure.
	if err := e.cmd("", nil, "ryoku", "doctor"); err != nil {
		e.say("note: ryoku doctor reported findings (see above); the install itself is done")
	}
	return nil
}

func stepVerify(e *engine) error {
	if e.dry {
		e.say("DRYRUN: verify [ryoku] repo, packages, session files")
		return nil
	}
	var bad []string
	check := func(ok bool, what string) {
		if ok {
			e.say(gCheck + " " + what)
		} else {
			bad = append(bad, what)
			e.say(gBad + " " + what)
		}
	}
	conf, _ := os.ReadFile("/etc/pacman.conf")
	check(strings.Contains(string(conf), "[ryoku]"), "[ryoku] repository in /etc/pacman.conf")
	check(pacmanHas("ryoku-keyring"), "ryoku-keyring package installed")
	check(pacmanHas("ryoku-desktop"), "ryoku-desktop package installed")
	check(has("ryoku"), "ryoku CLI on PATH")
	st, err := os.Stat("/usr/share/ryoku/config")
	check(err == nil && st.IsDir(), "base config tree at /usr/share/ryoku/config")
	_, err = os.Stat(filepath.Join(e.f.homeDir, ".config/hypr/hyprland.lua"))
	check(err == nil, "hyprland.lua materialized in ~/.config/hypr")
	_, err = os.Stat("/usr/share/wayland-sessions/hyprland.desktop")
	check(err == nil, "Hyprland wayland session registered")
	if e.p.switchDM {
		check(unitEnabled("system", "sddm.service"), "sddm.service enabled")
	}
	if !has("wallust") || !has("awww") {
		e.say(gWarn + " wallust/awww missing (AUR): wallpapers and palettes will not work until installed")
	}
	if len(bad) > 0 {
		return fmt.Errorf("%d check(s) failed: %s", len(bad), strings.Join(bad, "; "))
	}
	e.say("all checks passed")
	return nil
}

// ---- fs helpers ----

func copyTree(src, dst string) error {
	info, err := os.Lstat(src)
	if err != nil {
		return err
	}
	switch {
	case info.Mode()&os.ModeSymlink != 0:
		tgt, err := os.Readlink(src)
		if err != nil {
			return err
		}
		return os.Symlink(tgt, dst)
	case info.IsDir():
		if err := os.MkdirAll(dst, info.Mode().Perm()); err != nil {
			return err
		}
		ents, err := os.ReadDir(src)
		if err != nil {
			return err
		}
		for _, ent := range ents {
			if err := copyTree(filepath.Join(src, ent.Name()), filepath.Join(dst, ent.Name())); err != nil {
				return err
			}
		}
		return nil
	default:
		in, err := os.Open(src)
		if err != nil {
			return err
		}
		defer in.Close()
		out, err := os.OpenFile(dst, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, info.Mode().Perm())
		if err != nil {
			return err
		}
		defer out.Close()
		_, err = io.Copy(out, in)
		return err
	}
}

// seedPath copies src to dst. dirs merge without overwriting when ifAbsent
// (user wallpapers win); files honor ifAbsent per file.
func seedPath(src, dst string, dir, ifAbsent bool) error {
	if !dir {
		if ifAbsent {
			if _, err := os.Lstat(dst); err == nil {
				return nil
			}
		}
		if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
			return err
		}
		return copyTree(src, dst)
	}
	ents, err := os.ReadDir(src)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(dst, 0o755); err != nil {
		return err
	}
	for _, ent := range ents {
		s, d := filepath.Join(src, ent.Name()), filepath.Join(dst, ent.Name())
		if ifAbsent {
			if _, err := os.Lstat(d); err == nil {
				continue
			}
		} else if !ent.IsDir() {
			os.Remove(d)
		}
		if err := copyTree(s, d); err != nil {
			return err
		}
	}
	return nil
}
