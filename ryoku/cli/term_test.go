package main

import (
	"strings"
	"testing"
)

func TestWrapWidthAndIndent(t *testing.T) {
	got := wrap("the quick brown fox jumps over the lazy dog", 24, "  ")
	for _, l := range strings.Split(got, "\n") {
		if !strings.HasPrefix(l, "  ") {
			t.Errorf("line not indented: %q", l)
		}
		if len(l) > 24 {
			t.Errorf("line exceeds width 24: %q (len %d)", l, len(l))
		}
	}
	if !strings.Contains(got, "quick") || !strings.Contains(got, "lazy") {
		t.Error("wrap dropped words")
	}
}

func TestWrapKeepsParagraphBreaks(t *testing.T) {
	if got := wrap("alpha\nbeta", 40, ""); got != "alpha\nbeta" {
		t.Errorf("newlines should survive as breaks: %q", got)
	}
}
