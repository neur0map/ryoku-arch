package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func mkSkin(t *testing.T, dir, slug string, withPreview bool) {
	t.Helper()
	d := filepath.Join(dir, slug)
	if err := os.MkdirAll(d, 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(d, "Main.qml"), []byte("Rectangle{}"), 0o644); err != nil {
		t.Fatal(err)
	}
	if withPreview {
		if err := os.WriteFile(filepath.Join(d, "preview.gif"), []byte("GIF89a"), 0o644); err != nil {
			t.Fatal(err)
		}
	}
}

func findSkin(skins []LockSkin, slug string) *LockSkin {
	for i := range skins {
		if skins[i].Slug == slug {
			return &skins[i]
		}
	}
	return nil
}

func TestListLockSkinsIn(t *testing.T) {
	dir := t.TempDir()
	mkSkin(t, dir, "clockwork/orbital", true)
	mkSkin(t, dir, "clockwork/tape", false)
	// folder without Main.qml: not a skin, must be skipped.
	if err := os.MkdirAll(filepath.Join(dir, "clockwork", "notes"), 0o755); err != nil {
		t.Fatal(err)
	}

	resp := listLockSkinsIn(dir, "clockwork/tape")

	if resp.Active != "clockwork/tape" {
		t.Fatalf("active = %q, want clockwork/tape", resp.Active)
	}
	if len(resp.Skins) != 2 {
		t.Fatalf("got %d skins, want 2: %+v", len(resp.Skins), resp.Skins)
	}

	orb := findSkin(resp.Skins, "clockwork/orbital")
	tape := findSkin(resp.Skins, "clockwork/tape")
	if orb == nil || tape == nil {
		t.Fatalf("missing a skin: %+v", resp.Skins)
	}
	if orb.Name != "Orbital" || orb.Theme != "Clockwork" {
		t.Errorf("curated metadata not applied: %+v", orb)
	}
	if orb.Preview == "" {
		t.Errorf("orbital should report its preview.gif path")
	}
	if tape.Preview != "" {
		t.Errorf("tape has no preview.gif but reported %q", tape.Preview)
	}
	if orb.Active {
		t.Errorf("orbital marked active, but tape is selected")
	}
	if !tape.Active {
		t.Errorf("tape should be the active skin")
	}
}

func TestListLockSkinsInDerivesUncurated(t *testing.T) {
	dir := t.TempDir()
	// single-level theme, not in the curated map: name comes from the folder,
	// summary from metadata.desktop.
	mkSkin(t, dir, "nier-automata", false)
	desk := "[SddmGreeterTheme]\nName=nier\nDescription=A lonely android keeps the time\n"
	if err := os.WriteFile(filepath.Join(dir, "nier-automata", "metadata.desktop"), []byte(desk), 0o644); err != nil {
		t.Fatal(err)
	}

	resp := listLockSkinsIn(dir, "")
	s := findSkin(resp.Skins, "nier-automata")
	if s == nil {
		t.Fatalf("single-level skin not found: %+v", resp.Skins)
	}
	if s.Name != "Nier Automata" {
		t.Errorf("derived name = %q, want Nier Automata", s.Name)
	}
	if s.Summary != "A lonely android keeps the time" {
		t.Errorf("summary not read from metadata.desktop: %q", s.Summary)
	}
}

func TestSetLockSkinIn(t *testing.T) {
	dir := t.TempDir()
	mkSkin(t, dir, "clockwork/orbital", false)
	pref := filepath.Join(t.TempDir(), "qylock", "theme")

	if err := setLockSkinIn(dir, pref, "clockwork/orbital"); err != nil {
		t.Fatalf("set valid skin: %v", err)
	}
	if got := readLockPref(pref); got != "clockwork/orbital" {
		t.Fatalf("pref = %q, want clockwork/orbital", got)
	}

	// unknown slug -> reject. a bad value must never land in the pref.
	if err := setLockSkinIn(dir, pref, "ghost/none"); err == nil {
		t.Fatalf("setting an unknown skin should error")
	}
	if got := readLockPref(pref); got != "clockwork/orbital" {
		t.Fatalf("pref changed after a rejected set: %q", got)
	}
}

func TestInstallGreeter(t *testing.T) {
	src := t.TempDir()
	mkSkin(t, src, "material-you", false)
	themes := t.TempDir()
	conf := filepath.Join(t.TempDir(), "sddm.conf.d", "99-ryoku.conf")

	if err := installGreeter(src, themes, conf, "material-you"); err != nil {
		t.Fatalf("install greeter: %v", err)
	}
	if !fileExists(filepath.Join(themes, greeterTheme, "Main.qml")) {
		t.Fatalf("greeter theme %q not installed under %s", greeterTheme, themes)
	}
	b, err := os.ReadFile(conf)
	if err != nil {
		t.Fatalf("read conf: %v", err)
	}
	if !strings.Contains(string(b), "Current="+greeterTheme) {
		t.Fatalf("conf does not select the greeter theme: %q", b)
	}

	// second skin overwrites the same fixed greeter dir; nothing orphans.
	mkSkin(t, src, "clockwork/orbital", false)
	if err := installGreeter(src, themes, conf, "clockwork/orbital"); err != nil {
		t.Fatalf("reinstall greeter: %v", err)
	}
	if !fileExists(filepath.Join(themes, greeterTheme, "Main.qml")) {
		t.Fatalf("greeter theme missing after switch")
	}

	// unknown skin -> error before touching anything privileged.
	if err := installGreeter(src, themes, conf, "ghost/none"); err == nil {
		t.Fatalf("installing an unknown skin should error")
	}
}

func TestValidSlug(t *testing.T) {
	for _, ok := range []string{"clockwork/orbital", "material-you", "pixel-coffee"} {
		if err := validSlug(ok); err != nil {
			t.Errorf("validSlug(%q) = %v, want nil", ok, err)
		}
	}
	for _, bad := range []string{"", "/etc/passwd", "../../etc", "a/../b"} {
		if err := validSlug(bad); err == nil {
			t.Errorf("validSlug(%q) should error", bad)
		}
	}
}

// A skin pulled from the catalogue lands 0700 user-owned (os.MkdirTemp), but the
// greeter runs as the unprivileged `sddm` user: installGreeter must widen the
// copy to world-readable, else SDDM can't read the theme and silently falls back
// to its embedded one on every boot.
func TestInstallGreeterMakesThemeWorldReadable(t *testing.T) {
	src := t.TempDir()
	mkSkin(t, src, "video/tape", false)
	// mimic a catalogue download: owner-only perms on the skin tree.
	skin := filepath.Join(src, "video", "tape")
	if err := os.Chmod(filepath.Join(skin, "Main.qml"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Chmod(skin, 0o700); err != nil {
		t.Fatal(err)
	}
	themes := t.TempDir()
	conf := filepath.Join(t.TempDir(), "sddm.conf.d", "99-ryoku.conf")

	if err := installGreeter(src, themes, conf, "video/tape"); err != nil {
		t.Fatalf("install greeter: %v", err)
	}

	dir := filepath.Join(themes, greeterTheme)
	di, err := os.Stat(dir)
	if err != nil {
		t.Fatal(err)
	}
	if di.Mode().Perm()&0o005 != 0o005 {
		t.Errorf("greeter dir mode = %o, want world read+execute (o+rx)", di.Mode().Perm())
	}
	mi, err := os.Stat(filepath.Join(dir, "Main.qml"))
	if err != nil {
		t.Fatal(err)
	}
	if mi.Mode().Perm()&0o004 == 0 {
		t.Errorf("Main.qml mode = %o, want world readable (o+r)", mi.Mode().Perm())
	}
}
