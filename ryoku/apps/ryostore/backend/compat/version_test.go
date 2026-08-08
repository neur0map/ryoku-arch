package compat

import (
	"strings"
	"testing"
)

func TestRiceCompatibility(t *testing.T) {
	cases := map[string]string{
		"0.19.4|0.19.1": "ok",
		"0.18.9|0.19.1": "older",
		"0.20.0|0.19.1": "newer",
		"dev|0.19.1":    "unknown",
	}
	for in, want := range cases {
		parts := strings.Split(in, "|")
		if got := Rice(parts[0], parts[1]); got != want {
			t.Fatalf("%s = %s, want %s", in, got, want)
		}
	}
}

func TestRiceCompatibilityHandlesReleaseSuffixes(t *testing.T) {
	if got := Rice("0.19.0-beta.18", "v0.19.9"); got != "ok" {
		t.Fatalf("suffixed versions = %q, want ok", got)
	}
}
