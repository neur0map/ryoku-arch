package main

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"os/user"
	"path/filepath"
	"sort"
	"strings"
)

// ryoku-hub lock = the qylock skin picker behind Ryoku Settings. picking a skin
// swaps the whole lockscreen: the in-session lock pref at ~/.config/qylock/theme
// (lock.sh reads it) plus the SDDM greeter theme under /usr/share/sddm/themes.
// the greeter sits on a system path so that half goes through pkexec
// (apply-greeter); auth itself stays untouched.
//
//	ryoku-hub lock list           installed skins + active one, as JSON
//	ryoku-hub lock set <slug>     make a skin the lock + greeter (pkexec for greeter)
//	ryoku-hub lock apply-greeter  install <slug> as SDDM greeter (privileged; pkexec runs this)
//
// a skin = any folder under the themes dir with a Main.qml. slug = its path
// under that dir (e.g. "clockwork/orbital"), exactly what lock.sh resolves
// against themes_link.

// LockSkin = one selectable skin as the Hub draws it.
type LockSkin struct {
	Slug      string   `json:"slug"`    // path under the themes dir, e.g. "clockwork/orbital"
	Name      string   `json:"name"`    // "Orbital"
	Theme     string   `json:"theme"`   // "Clockwork"
	Summary   string   `json:"summary"` // one line
	Blurb     string   `json:"blurb"`   // a sentence
	Tags      []string `json:"tags"`
	Preview   string   `json:"preview"`   // gif: file://... local, https://... upstream, "" none
	Installed bool     `json:"installed"` // present under qylock themes dir
	Active    bool     `json:"active"`
	SizeKB    int      `json:"sizeKB"` // upstream install weight, 0 when unknown
}

// LockResponse = the `ryoku-hub lock catalog` / `list` payload: active slug,
// the skins, plus whether the upstream qylock repo was reachable.
type LockResponse struct {
	Active string     `json:"active"`
	Online bool       `json:"online"`
	Skins  []LockSkin `json:"skins"`
}

// lockCurated: hand-written copy for the skins Ryoku ships. anything not in
// here falls back to folder name + metadata.desktop so a stray hand-dropped
// qylock theme still shows up with something readable.
var lockCurated = map[string]LockSkin{
	"clockwork/orbital": {
		Name: "Orbital", Theme: "Clockwork", Tags: []string{"Clockwork"},
		Summary: "An orbital clock that winds up to unlock",
		Blurb:   "Concentric minute and second rings sweep past a bold hour readout; typing your key winds the mechanism before it springs open.",
	},
	"clockwork/tape": {
		Name: "Tape", Theme: "Clockwork", Tags: []string{"Clockwork"},
		Summary: "Time on warm, scrolling film reels",
		Blurb:   "Hours, minutes, and seconds roll past on sprocketed tape behind an amber readout beam, like a frame of film paused at now.",
	},
}

func xdgHome(env, sub string) string {
	if base := os.Getenv(env); base != "" {
		return base
	}
	return filepath.Join(os.Getenv("HOME"), sub)
}

func qylockThemesDir() string {
	return filepath.Join(xdgHome("XDG_DATA_HOME", ".local/share"), "qylock", "themes")
}

func qylockThemePref() string {
	return filepath.Join(xdgHome("XDG_CONFIG_HOME", ".config"), "qylock", "theme")
}

// runLock = `ryoku-hub lock <sub> [arg]` dispatch.
func runLock(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("lock needs catalog|list|set|install")
	}
	switch args[0] {
	case "catalog":
		return printJSON(lockCatalog())
	case "list":
		return printJSON(listLockSkins())
	case "set":
		if len(args) < 2 {
			return fmt.Errorf("lock set needs a slug")
		}
		return setLockSkin(args[1])
	case "install":
		if len(args) < 2 {
			return fmt.Errorf("lock install needs a slug")
		}
		return lockInstall(args[1])
	case "apply-greeter":
		if len(args) < 2 {
			return fmt.Errorf("lock apply-greeter needs a slug")
		}
		return applyGreeter(args[1])
	default:
		return fmt.Errorf("lock needs catalog|list|set|install")
	}
}

func listLockSkins() LockResponse {
	return listLockSkinsIn(qylockThemesDir(), readLockPref(qylockThemePref()))
}

// readLockPref: active slug (trimmed). missing file -> "".
func readLockPref(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

// listLockSkinsIn: scan dir, mark whichever slug matches active. split out
// from listLockSkins so a temp tree can drive it from tests.
func listLockSkinsIn(dir, active string) LockResponse {
	skins := []LockSkin{}
	for _, slug := range scanLockSlugs(dir) {
		s := lockSkinFor(dir, slug)
		s.Active = slug == active
		skins = append(skins, s)
	}
	sort.Slice(skins, func(i, j int) bool {
		if skins[i].Theme != skins[j].Theme {
			return skins[i].Theme < skins[j].Theme
		}
		return skins[i].Name < skins[j].Name
	})
	return LockResponse{Active: active, Skins: skins}
}

// scanLockSlugs walks two levels deep (theme, theme/variant) for any folder
// that has a Main.qml, returning the slug (path under dir).
func scanLockSlugs(dir string) []string {
	var slugs []string
	tops, _ := os.ReadDir(dir)
	for _, t := range tops {
		if !t.IsDir() {
			continue
		}
		if fileExists(filepath.Join(dir, t.Name(), "Main.qml")) {
			slugs = append(slugs, t.Name())
			continue
		}
		subs, _ := os.ReadDir(filepath.Join(dir, t.Name()))
		for _, s := range subs {
			if s.IsDir() && fileExists(filepath.Join(dir, t.Name(), s.Name(), "Main.qml")) {
				slugs = append(slugs, t.Name()+"/"+s.Name())
			}
		}
	}
	return slugs
}

func lockSkinFor(dir, slug string) LockSkin {
	s := lockSkinMeta(dir, slug)
	s.Installed = true
	if p := filepath.Join(dir, slug, "preview.gif"); fileExists(p) {
		s.Preview = "file://" + p
	}
	return s
}

// lockSkinMeta fills the display copy: curated map first, else a name+tag
// guess from the slug plus, for an installed skin, the summary from
// metadata.desktop. doesn't touch Preview / Installed / Active.
func lockSkinMeta(dir, slug string) LockSkin {
	if c, ok := lockCurated[slug]; ok {
		return LockSkin{Slug: slug, Name: c.Name, Theme: c.Theme, Summary: c.Summary, Blurb: c.Blurb, Tags: c.Tags}
	}
	s := LockSkin{Slug: slug, Name: lockSkinName(slug), Tags: lockSkinTags(slug)}
	if len(s.Tags) > 0 {
		s.Theme = s.Tags[0]
	}
	s.Summary = lockDesktopDescription(filepath.Join(dir, slug, "metadata.desktop"))
	return s
}

// lockSkinName: slug -> display name. take the leaf, swap separators for
// spaces, capitalise each word ("pixel-coffee" -> "Pixel Coffee").
func lockSkinName(slug string) string {
	leaf := slug
	if i := strings.LastIndex(slug, "/"); i >= 0 {
		leaf = slug[i+1:]
	}
	words := strings.Fields(strings.NewReplacer("-", " ", "_", " ").Replace(leaf))
	for i, w := range words {
		words[i] = titleWord(w)
	}
	return strings.Join(words, " ")
}

// lockSkinTags groups the obvious qylock families so siblings share a label.
func lockSkinTags(slug string) []string {
	switch {
	case strings.HasPrefix(slug, "clockwork"):
		return []string{"Clockwork"}
	case strings.HasPrefix(slug, "pixel-"):
		return []string{"Pixel"}
	case strings.HasPrefix(slug, "R1999"):
		return []string{"Reverse 1999"}
	}
	return nil
}

func setLockSkin(slug string) error {
	dir := qylockThemesDir()
	if !fileExists(filepath.Join(dir, slug, "Main.qml")) {
		return fmt.Errorf("unknown lock skin: %s", slug)
	}
	if err := escalateGreeter(slug); err != nil {
		return err
	}
	return setLockSkinIn(dir, qylockThemePref(), slug)
}

// setLockSkinIn writes slug to the active-lock pref file. an unknown slug is
// rejected here so a typo can't quietly disable the lock.
func setLockSkinIn(dir, pref, slug string) error {
	if !fileExists(filepath.Join(dir, slug, "Main.qml")) {
		return fmt.Errorf("unknown lock skin: %s", slug)
	}
	if err := os.MkdirAll(filepath.Dir(pref), 0o755); err != nil {
		return err
	}
	return atomicWrite(pref, []byte(slug+"\n"), 0o644)
}

const greeterTheme = "ryoku"

func sddmThemesDir() string {
	if v := os.Getenv("RYOKU_SDDM_THEMES_DIR"); v != "" {
		return v
	}
	return "/usr/share/sddm/themes"
}

func sddmConfPath() string {
	if v := os.Getenv("RYOKU_SDDM_CONF"); v != "" {
		return v
	}
	return "/etc/sddm.conf.d/99-ryoku.conf"
}

// validSlug: kill empty / absolute / traversing slugs before they hit a
// filesystem path or a privileged copy.
func validSlug(slug string) error {
	if slug == "" || strings.HasPrefix(slug, "/") || strings.Contains(slug, "..") {
		return fmt.Errorf("invalid skin slug: %q", slug)
	}
	return nil
}

// escalateGreeter re-execs this binary under pkexec to install the skin as the
// SDDM greeter (it has to write /usr/share/sddm + /etc). pkexec pops the
// graphical polkit prompt; cancel -> error.
func escalateGreeter(slug string) error {
	self, err := os.Executable()
	if err != nil {
		return err
	}
	cmd := exec.Command("pkexec", self, "lock", "apply-greeter", slug)
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stderr
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("sign-in screen needs admin authentication: %w", err)
	}
	return nil
}

// applyGreeter = the privileged half, run as root by pkexec. installs the
// skin the invoking user picked as the greeter. source resolves from the
// invoking user's home, never from a caller-supplied path. don't change that.
func applyGreeter(slug string) error {
	src := os.Getenv("RYOKU_QYLOCK_THEMES")
	if src == "" {
		src = invokingUserThemes()
	}
	return installGreeter(src, sddmThemesDir(), sddmConfPath(), slug)
}

// invokingUserThemes: qylock themes dir of whoever invoked us via pkexec
// (PKEXEC_UID) or sudo (SUDO_UID), so root reads the right home.
func invokingUserThemes() string {
	uid := os.Getenv("PKEXEC_UID")
	if uid == "" {
		uid = os.Getenv("SUDO_UID")
	}
	if uid != "" {
		if u, err := user.LookupId(uid); err == nil {
			return filepath.Join(u.HomeDir, ".local", "share", "qylock", "themes")
		}
	}
	return qylockThemesDir()
}

// installGreeter copies srcThemes/slug into themesDir under a fixed name and
// points the greeter config at it, so the login screen wears the same skin as
// the in-session lock. privileged; broken out for tests.
func installGreeter(srcThemes, themesDir, confPath, slug string) error {
	if err := validSlug(slug); err != nil {
		return err
	}
	src := filepath.Join(srcThemes, slug)
	if !fileExists(filepath.Join(src, "Main.qml")) {
		return fmt.Errorf("not an installed skin: %s", slug)
	}
	dst := filepath.Join(themesDir, greeterTheme)
	if err := os.MkdirAll(themesDir, 0o755); err != nil {
		return err
	}
	if err := os.RemoveAll(dst); err != nil {
		return err
	}
	if out, err := exec.Command("cp", "-a", src, dst).CombinedOutput(); err != nil {
		return fmt.Errorf("install greeter theme: %v: %s", err, out)
	}
	// The greeter runs as the unprivileged `sddm` user, so it must be able to
	// read the theme no matter how the source was owned or masked. Catalog skins
	// download into an os.MkdirTemp dir (always 0700) and `cp -a` preserves that,
	// leaving the greeter dir unreadable to sddm -> SDDM silently falls back to
	// its embedded theme on every boot. Normalize: root-owned (best effort, since
	// this half runs as root under pkexec) and world-readable.
	_ = exec.Command("chown", "-R", "root:root", dst).Run()
	if out, err := exec.Command("chmod", "-R", "a+rX", dst).CombinedOutput(); err != nil {
		return fmt.Errorf("make greeter theme readable: %v: %s", err, out)
	}
	if err := os.MkdirAll(filepath.Dir(confPath), 0o755); err != nil {
		return err
	}
	return atomicWrite(confPath, []byte("[Theme]\nCurrent="+greeterTheme+"\n"), 0o644)
}

func fileExists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}

// titleWord: upper-case the first rune. "orbital" -> "Orbital".
func titleWord(s string) string {
	if s == "" {
		return s
	}
	return strings.ToUpper(s[:1]) + s[1:]
}

// lockDesktopDescription: pull Description= from a freedesktop-style file.
// best effort, any error -> "".
func lockDesktopDescription(path string) string {
	f, err := os.Open(path)
	if err != nil {
		return ""
	}
	defer f.Close()
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		if v, ok := strings.CutPrefix(strings.TrimSpace(sc.Text()), "Description="); ok {
			return strings.TrimSpace(v)
		}
	}
	return ""
}
