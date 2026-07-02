package main

import (
	"regexp"
	"testing"
)

func TestParseOSRelease(t *testing.T) {
	id, like, name := parseOSRelease("NAME=\"CachyOS\"\nPRETTY_NAME=\"CachyOS Linux\"\nID=cachyos\nID_LIKE=\"arch\"\n")
	if id != "cachyos" || like != "arch" || name != "CachyOS Linux" {
		t.Fatalf("got %q %q %q", id, like, name)
	}
}

func TestNiriLayout(t *testing.T) {
	cfg := "input {\n    keyboard {\n        xkb {\n            layout \"us,de\"\n        }\n    }\n}\n"
	if got := niriLayout(cfg); got != "us,de" {
		t.Fatalf("got %q", got)
	}
	if got := niriLayout("output \"DP-1\" {}"); got != "" {
		t.Fatalf("expected empty, got %q", got)
	}
}

func TestShellJoin(t *testing.T) {
	if got := shellJoin("pacman", []string{"-S", "a b"}); got != "pacman -S \"a b\"" {
		t.Fatalf("got %q", got)
	}
}

func TestStripPacmanSection(t *testing.T) {
	conf := "[options]\nColor\n\n[core]\nInclude = /etc/pacman.d/mirrorlist\n\n[omarchy]\nSigLevel = Required\nServer = https://pkgs.omarchy.org/$arch\n\n[extra]\nInclude = /etc/pacman.d/mirrorlist\n"
	got := stripPacmanSection(conf, "omarchy")
	if regexp.MustCompile(`\[omarchy\]|omarchy\.org`).MatchString(got) {
		t.Fatalf("omarchy section survived:\n%s", got)
	}
	for _, keep := range []string{"[options]", "[core]", "[extra]", "Color"} {
		if !regexp.MustCompile(regexp.QuoteMeta(keep)).MatchString(got) {
			t.Fatalf("lost %q:\n%s", keep, got)
		}
	}
	// no section match leaves the file untouched.
	if stripPacmanSection(conf, "nope") != conf {
		t.Fatal("stripping an absent section changed the file")
	}
}

func TestMirrorlistHasOmarchy(t *testing.T) {
	if !mirrorlistHasOmarchy("# comment\nServer = https://stable-mirror.omarchy.org/$repo/os/$arch\n") {
		t.Fatal("missed the omarchy mirror")
	}
	if mirrorlistHasOmarchy("# omarchy used to live here\nServer = https://geo.mirror.pkgbuild.com/$repo/os/$arch\n") {
		t.Fatal("a comment mentioning omarchy must not count")
	}
}
