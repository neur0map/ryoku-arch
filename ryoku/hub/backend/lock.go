package main

import (
	"bufio"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

// ryoku-hub lock exposes the qylock in-session lock skins to Ryoku Settings.
// Ryoku ships the "clockwork" theme; this section only swaps which skin the lock
// wears, the user-level preference at ~/.config/qylock/theme that lock.sh reads.
// It never touches the SDDM greeter or the authentication flow, so the login
// logic stays exactly as installed.
//
//	ryoku-hub lock list          print the installed skins + the active one as JSON
//	ryoku-hub lock set <slug>    set the active skin (writes ~/.config/qylock/theme)
//
// A skin is any folder under the qylock themes dir that holds a Main.qml; its
// slug is that folder's path under the themes dir (e.g. "clockwork/orbital"),
// exactly the value lock.sh resolves against themes_link.

// LockSkin is one selectable lock skin as the Hub renders it.
type LockSkin struct {
	Slug      string   `json:"slug"`    // path under the themes dir, e.g. "clockwork/orbital"
	Name      string   `json:"name"`    // "Orbital"
	Theme     string   `json:"theme"`   // "Clockwork"
	Summary   string   `json:"summary"` // one line
	Blurb     string   `json:"blurb"`   // a sentence
	Tags      []string `json:"tags"`
	Preview   string   `json:"preview"`   // gif source URI: file://... local, https://... upstream, "" none
	Installed bool     `json:"installed"` // present under the qylock themes dir
	Active    bool     `json:"active"`
	SizeKB    int      `json:"sizeKB"` // upstream install weight; 0 when unknown
}

// LockResponse is `ryoku-hub lock catalog` (and `list`): the active skin, the
// skins, and whether the listing reached the upstream qylock repo.
type LockResponse struct {
	Active string     `json:"active"`
	Online bool       `json:"online"`
	Skins  []LockSkin `json:"skins"`
}

// lockCurated carries the copy for the skins Ryoku ships. Any skin not listed
// falls back to metadata derived from its folder and metadata.desktop, so a
// hand-dropped qylock theme still appears with a sensible name.
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

// runLock dispatches `ryoku-hub lock <sub> [arg]`.
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
	default:
		return fmt.Errorf("lock needs catalog|list|set|install")
	}
}

func listLockSkins() LockResponse {
	return listLockSkinsIn(qylockThemesDir(), readLockPref(qylockThemePref()))
}

// readLockPref returns the active slug (trimmed); a missing file yields "".
func readLockPref(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

// listLockSkinsIn scans dir for skins and flags the one matching active. Split
// from listLockSkins so it is testable against a temp tree.
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

// scanLockSlugs walks at most two levels (theme, then theme/variant) for folders
// holding a Main.qml, returning each one's slug (path under dir).
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

// lockSkinMeta fills a skin's display copy from the curated map, falling back to
// a name and tag derived from the slug and, for an installed skin, the summary
// from its metadata.desktop. It sets neither Preview, Installed, nor Active.
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

// lockSkinName turns a slug into a display name: the leaf segment with separators
// spaced out and each word capitalised ("pixel-coffee" -> "Pixel Coffee").
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

// lockSkinTags groups the obvious qylock families so kindred skins share a label.
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
	return setLockSkinIn(qylockThemesDir(), qylockThemePref(), slug)
}

// setLockSkinIn writes slug as the active lock preference, rejecting a slug that
// does not name an installed skin so a typo never disables the lock.
func setLockSkinIn(dir, pref, slug string) error {
	if !fileExists(filepath.Join(dir, slug, "Main.qml")) {
		return fmt.Errorf("unknown lock skin: %s", slug)
	}
	if err := os.MkdirAll(filepath.Dir(pref), 0o755); err != nil {
		return err
	}
	return atomicWrite(pref, []byte(slug+"\n"), 0o644)
}

func fileExists(p string) bool {
	_, err := os.Stat(p)
	return err == nil
}

// titleWord upper-cases the first rune so "orbital" reads "Orbital".
func titleWord(s string) string {
	if s == "" {
		return s
	}
	return strings.ToUpper(s[:1]) + s[1:]
}

// lockDesktopDescription pulls Description= from a freedesktop-style file, best
// effort: any error yields "".
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
