package main

import (
	"os"
	"path/filepath"
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
	// A folder with no Main.qml is not a skin and must be skipped.
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
	// A single-level theme that isn't in the curated map: name derives from the
	// folder, summary from metadata.desktop.
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
	if s.Name != "Nier-automata" {
		t.Errorf("derived name = %q, want Nier-automata", s.Name)
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

	// An unknown slug must be rejected so a bad value never lands in the pref.
	if err := setLockSkinIn(dir, pref, "ghost/none"); err == nil {
		t.Fatalf("setting an unknown skin should error")
	}
	if got := readLockPref(pref); got != "clockwork/orbital" {
		t.Fatalf("pref changed after a rejected set: %q", got)
	}
}
