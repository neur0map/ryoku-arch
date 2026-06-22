package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

// The Lockscreen catalogue browses the full qylock theme set live from the
// upstream repo, so new and fixed skins appear without a Ryoku release. The two
// vendored skins (clockwork/orbital, clockwork/tape) are the offline baseline;
// every other theme is previewed from the upstream Assets gif and downloaded
// into ~/.local/share/qylock/themes on first select.
//
//	ryoku-hub lock catalog        themes from upstream (installed-only when offline)
//	ryoku-hub lock install <slug> download a theme's files, then make it active
//
// A theme is any folder under themes/ holding a Main.qml; its slug is that path
// (e.g. "clockwork/orbital"). Preview gifs live in Assets/ under names that do
// not always match the theme folder, so the match normalises both sides and a
// small alias table covers the two upstream names that still diverge.

const (
	qylockOwnerRepo = "Darkkal44/qylock"
	qylockBranch    = "main"
)

// The host is overridable so a fork (or a local fixture under test) can stand in.
func qylockAPIBase() string {
	if v := os.Getenv("RYOKU_QYLOCK_API"); v != "" {
		return v
	}
	return "https://api.github.com"
}

func qylockRawBase() string {
	if v := os.Getenv("RYOKU_QYLOCK_RAW"); v != "" {
		return v
	}
	return "https://raw.githubusercontent.com"
}

func qylockTreeURL() string {
	return fmt.Sprintf("%s/repos/%s/git/trees/%s?recursive=1", qylockAPIBase(), qylockOwnerRepo, qylockBranch)
}

func qylockRawURL(path string) string {
	return fmt.Sprintf("%s/%s/%s/%s", qylockRawBase(), qylockOwnerRepo, qylockBranch, path)
}

var (
	lockHTTP         = &http.Client{Timeout: 25 * time.Second}
	lockDownloadHTTP = &http.Client{Timeout: 5 * time.Minute}
)

// qylock theme folders whose Assets gif name does not normalise to the folder.
var lockGifAlias = map[string]string{
	"last-of-us": "the_last_of_us",
	"windows_7":  "win7",
}

type ghTreeEntry struct {
	Path string `json:"path"`
	Type string `json:"type"`
	Size int    `json:"size"`
}

type ghTree struct {
	Tree      []ghTreeEntry `json:"tree"`
	Truncated bool          `json:"truncated"`
}

// qylockTree is the parsed catalogue input: theme slugs, the set of Assets gif
// basenames, and per-theme file list and total byte size.
type qylockTree struct {
	Themes []string
	Gifs   map[string]bool
	Files  map[string][]string // slug -> relative file paths
	SizeKB map[string]int      // slug -> total file size in KB
}

func parseQylockTree(b []byte) (qylockTree, error) {
	var t ghTree
	if err := json.Unmarshal(b, &t); err != nil {
		return qylockTree{}, err
	}
	out := qylockTree{Gifs: map[string]bool{}, Files: map[string][]string{}, SizeKB: map[string]int{}}
	for _, e := range t.Tree {
		switch {
		case strings.HasPrefix(e.Path, "Assets/") && strings.HasSuffix(e.Path, ".gif"):
			out.Gifs[strings.TrimSuffix(strings.TrimPrefix(e.Path, "Assets/"), ".gif")] = true
		case strings.HasPrefix(e.Path, "themes/") && e.Type == "blob" && strings.HasSuffix(e.Path, "/Main.qml"):
			out.Themes = append(out.Themes, strings.TrimSuffix(strings.TrimPrefix(e.Path, "themes/"), "/Main.qml"))
		}
	}
	sort.Strings(out.Themes)
	bytes := map[string]int{}
	for _, e := range t.Tree {
		if e.Type != "blob" || !strings.HasPrefix(e.Path, "themes/") {
			continue
		}
		rel := strings.TrimPrefix(e.Path, "themes/")
		for _, slug := range out.Themes {
			if strings.HasPrefix(rel, slug+"/") {
				out.Files[slug] = append(out.Files[slug], rel[len(slug)+1:])
				bytes[slug] += e.Size
				break
			}
		}
	}
	for slug, n := range bytes {
		out.SizeKB[slug] = n / 1024
	}
	return out, nil
}

// lockNorm lowercases and strips every non-alphanumeric rune so theme folders and
// gif names compare on letters alone ("pixel-coffee" and "pixel_coffee" agree).
func lockNorm(s string) string {
	var b strings.Builder
	for _, r := range strings.ToLower(s) {
		if (r >= 'a' && r <= 'z') || (r >= '0' && r <= '9') {
			b.WriteRune(r)
		}
	}
	return b.String()
}

// mapThemeGif returns the Assets gif basename for a theme slug: an alias when one
// is registered, else the gif whose normalised name matches the theme's top
// segment (so both clockwork variants share clockwork.gif). ok is false when none.
func mapThemeGif(slug string, gifs map[string]bool) (string, bool) {
	top := slug
	if i := strings.Index(slug, "/"); i >= 0 {
		top = slug[:i]
	}
	if a, ok := lockGifAlias[slug]; ok {
		return a, gifs[a]
	}
	if a, ok := lockGifAlias[top]; ok {
		return a, gifs[a]
	}
	want := lockNorm(top)
	for g := range gifs {
		if lockNorm(g) == want {
			return g, true
		}
	}
	return "", false
}

// buildLockCatalog turns the parsed tree into the catalogue, flagging installed
// and active skins and resolving each preview to a local gif when one ships,
// otherwise the upstream Assets gif streamed straight from the repo. Pure: the
// caller supplies the tree, the themes dir, and the active slug.
func buildLockCatalog(tree qylockTree, themesDir, active string) LockResponse {
	skins := make([]LockSkin, 0, len(tree.Themes))
	for _, slug := range tree.Themes {
		s := lockSkinMeta(themesDir, slug)
		s.Installed = fileExists(filepath.Join(themesDir, slug, "Main.qml"))
		s.Active = slug == active
		s.SizeKB = tree.SizeKB[slug]
		if local := filepath.Join(themesDir, slug, "preview.gif"); s.Installed && fileExists(local) {
			s.Preview = "file://" + local
		} else if gif, ok := mapThemeGif(slug, tree.Gifs); ok {
			s.Preview = qylockRawURL("Assets/" + gif + ".gif")
		}
		skins = append(skins, s)
	}
	sort.SliceStable(skins, func(i, j int) bool {
		if skins[i].Active != skins[j].Active {
			return skins[i].Active
		}
		if skins[i].Installed != skins[j].Installed {
			return skins[i].Installed
		}
		return skins[i].Name < skins[j].Name
	})
	return LockResponse{Active: active, Online: true, Skins: skins}
}

// lockCatalog fetches the upstream tree and builds the live catalogue, falling
// back to the installed-only listing when the repo is unreachable so the section
// still works offline.
func lockCatalog() LockResponse {
	b, err := fetchQylockTree()
	if err != nil {
		return listLockSkins()
	}
	tree, err := parseQylockTree(b)
	if err != nil || len(tree.Themes) == 0 {
		return listLockSkins()
	}
	return buildLockCatalog(tree, qylockThemesDir(), readLockPref(qylockThemePref()))
}

func fetchQylockTree() ([]byte, error) {
	req, err := http.NewRequest(http.MethodGet, qylockTreeURL(), nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	req.Header.Set("User-Agent", "ryoku-hub")
	resp, err := lockHTTP.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("qylock tree: %s", resp.Status)
	}
	return io.ReadAll(io.LimitReader(resp.Body, 8<<20))
}

// lockInstall downloads every file of a theme from upstream into the qylock themes
// dir, then makes it the active skin.
func lockInstall(slug string) error {
	return lockInstallTo(qylockThemesDir(), qylockThemePref(), slug)
}

// lockInstallTo downloads into a sibling temp dir on the same filesystem and moves
// the theme into place only on full success, so a failed or partial download never
// leaves a half-written, unbootable theme under the themes dir.
func lockInstallTo(themesDir, pref, slug string) error {
	b, err := fetchQylockTree()
	if err != nil {
		return fmt.Errorf("reach qylock: %w", err)
	}
	tree, err := parseQylockTree(b)
	if err != nil {
		return err
	}
	files := tree.Files[slug]
	if len(files) == 0 {
		return fmt.Errorf("unknown lock skin: %s", slug)
	}

	parent := filepath.Dir(themesDir)
	if err := os.MkdirAll(parent, 0o755); err != nil {
		return err
	}
	tmp, err := os.MkdirTemp(parent, ".lock-install-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmp)

	for _, rel := range files {
		if err := downloadFile(qylockRawURL("themes/"+slug+"/"+rel), filepath.Join(tmp, rel)); err != nil {
			return fmt.Errorf("download %s: %w", rel, err)
		}
	}

	dst := filepath.Join(themesDir, slug)
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	_ = os.RemoveAll(dst)
	if err := os.Rename(tmp, dst); err != nil {
		return err
	}
	return setLockSkinIn(themesDir, pref, slug)
}

func downloadFile(url, dst string) error {
	req, err := http.NewRequest(http.MethodGet, url, nil)
	if err != nil {
		return err
	}
	req.Header.Set("User-Agent", "ryoku-hub")
	resp, err := lockDownloadHTTP.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("%s: %s", url, resp.Status)
	}
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	f, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer f.Close()
	_, err = io.Copy(f, resp.Body)
	return err
}
