package main

import (
	"bytes"
	"os"
	"path/filepath"
	"testing"
)

// a compact profile.json: hero.kind=custom with a bare source name, plus a few
// other fields. Compact so the verbatim-carry round-trip is byte-exact.
const sampleProfile = `{"preset":"full","heroSide":"right","hero":{"kind":"custom","source":"hero.png","focalX":0.5,"focalY":0.4,"zoom":1,"invert":false},"text":{"name":"Nero","tagline":"力"},"vitals":["core","gpu"]}`

// a short blob of arbitrary bytes standing in for the custom hero image; the
// round-trip must restore these exactly.
var sampleHero = []byte{0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a, 0x00, 0x01, 0x02, 0xff, 0xfe}

func TestProfileRoundTrip(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)

	if err := os.MkdirAll(profileDir(), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(profileConfigPath(), []byte(sampleProfile), 0o644); err != nil {
		t.Fatal(err)
	}
	heroPath := filepath.Join(profileHeroDir(), "hero.png")
	if err := os.MkdirAll(profileHeroDir(), 0o755); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(heroPath, sampleHero, 0o644); err != nil {
		t.Fatal(err)
	}

	dst := filepath.Join(t.TempDir(), "share.ryoprofile")
	if err := exportProfile(dst); err != nil {
		t.Fatalf("exportProfile: %v", err)
	}

	// wipe the live state so import has to restore it from the envelope alone.
	if err := os.Remove(profileConfigPath()); err != nil {
		t.Fatal(err)
	}
	if err := os.Remove(heroPath); err != nil {
		t.Fatal(err)
	}

	if err := importProfile(dst); err != nil {
		t.Fatalf("importProfile: %v", err)
	}

	got, err := os.ReadFile(profileConfigPath())
	if err != nil {
		t.Fatalf("read restored profile.json: %v", err)
	}
	if string(got) != sampleProfile {
		t.Fatalf("profile.json not restored exactly:\n want %s\n got  %s", sampleProfile, got)
	}
	gotHero, err := os.ReadFile(heroPath)
	if err != nil {
		t.Fatalf("read restored hero: %v", err)
	}
	if !bytes.Equal(gotHero, sampleHero) {
		t.Fatalf("hero bytes not restored exactly:\n want %v\n got  %v", sampleHero, gotHero)
	}
}

func TestProfileImportRejectsGarbage(t *testing.T) {
	dir := t.TempDir()
	t.Setenv("XDG_CONFIG_HOME", dir)

	garbage := filepath.Join(t.TempDir(), "bad.ryoprofile")
	if err := os.WriteFile(garbage, []byte(`{"profile":{"preset":"full"}}`), 0o644); err != nil {
		t.Fatal(err)
	}

	if err := importProfile(garbage); err == nil {
		t.Fatal("importProfile accepted a file lacking ryoprofile:1")
	}
	if _, err := os.Stat(profileConfigPath()); !os.IsNotExist(err) {
		t.Fatalf("profile.json must not exist after a rejected import, stat err = %v", err)
	}
}
