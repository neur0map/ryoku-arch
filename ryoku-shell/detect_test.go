package main

import "testing"

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
