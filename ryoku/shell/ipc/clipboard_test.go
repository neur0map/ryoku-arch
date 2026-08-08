package main

import (
	"bytes"
	"fmt"
	"image"
	"image/png"
	"os"
	"path/filepath"
	"reflect"
	"strings"
	"testing"
)

func clipIDs(s *clipState) []uint64 {
	ids := make([]uint64, len(s.entries))
	for i, e := range s.entries {
		ids[i] = e.ID
	}
	return ids
}

func tinyPNG(t *testing.T, w, h int) []byte {
	t.Helper()
	var buf bytes.Buffer
	if err := png.Encode(&buf, image.NewRGBA(image.Rect(0, 0, w, h))); err != nil {
		t.Fatal(err)
	}
	return buf.Bytes()
}

// The history rules are the clipboard's contract: newest-first order, one id per
// distinct content, a repeat promoted to the front reusing its id (no
// duplicate), and a hard 100-entry cap that drops the oldest.
func TestClipHistoryRules(t *testing.T) {
	s := &clipState{}
	for i, h := range []uint64{100, 200, 300} {
		s.pushLocked(&clipEntry{hash: h, Kind: "text", Preview: fmt.Sprintf("e%d", i)})
	}
	if got := clipIDs(s); !reflect.DeepEqual(got, []uint64{3, 2, 1}) {
		t.Fatalf("three pushes, ids front-to-back = %v, want [3 2 1]", got)
	}

	// A repeat of the oldest content promotes to the front and reuses its id.
	s.pushLocked(&clipEntry{hash: 100, Kind: "text", Preview: "dup"})
	if len(s.entries) != 3 {
		t.Fatalf("dedup kept a duplicate: len = %d, want 3", len(s.entries))
	}
	if got := clipIDs(s); !reflect.DeepEqual(got, []uint64{1, 3, 2}) {
		t.Fatalf("after dedup, ids front-to-back = %v, want [1 3 2]", got)
	}
	if s.entries[0].Preview != "dup" {
		t.Errorf("promoted entry not refreshed: preview = %q", s.entries[0].Preview)
	}

	// The cap drops the oldest once a new entry overflows it.
	s = &clipState{}
	n := clipMaxEntries + 5
	for i := range n {
		s.pushLocked(&clipEntry{hash: uint64(1000 + i)})
	}
	if len(s.entries) != clipMaxEntries {
		t.Fatalf("cap not enforced: len = %d, want %d", len(s.entries), clipMaxEntries)
	}
	if s.entries[0].ID != uint64(n) {
		t.Errorf("front id = %d, want %d (newest)", s.entries[0].ID, n)
	}
	if s.entries[len(s.entries)-1].ID != 6 {
		t.Errorf("oldest surviving id = %d, want 6 (ids 1-5 evicted)", s.entries[len(s.entries)-1].ID)
	}
}

// copy_entry promotes an existing entry to the front, keeping its id.
func TestClipPromote(t *testing.T) {
	s := &clipState{}
	for _, h := range []uint64{10, 20, 30} {
		s.pushLocked(&clipEntry{hash: h})
	}
	if e := s.promoteLocked(1); e == nil {
		t.Fatal("promoteLocked(1) = nil, want the id-1 entry")
	}
	if got := clipIDs(s); !reflect.DeepEqual(got, []uint64{1, 3, 2}) {
		t.Fatalf("after promote, ids = %v, want [1 3 2]", got)
	}
	if s.promoteLocked(99) != nil {
		t.Error("promoteLocked of an unknown id should be nil")
	}
}

// classifyClip is the preview contract: text keeps a 200-character preview,
// a decodable image gets a thumbnail, an undecodable image falls to binary, and
// any other type is binary.
func TestClassifyClip(t *testing.T) {
	kind, preview, thumb, _, _ := classifyClip("text/plain", []byte(strings.Repeat("a", 250)))
	if kind != "text" || len([]rune(preview)) != clipTextPreviewLen || thumb != nil {
		t.Errorf("text classify = (%q, %d-rune preview, thumb=%v), want (text, 200, false)", kind, len([]rune(preview)), thumb != nil)
	}

	kind, _, thumb, w, h := classifyClip("image/png", tinyPNG(t, 8, 4))
	if kind != "image" || thumb == nil || w != 8 || h != 4 {
		t.Errorf("png classify = (%q, thumb=%v, %dx%d), want (image, true, 8x4)", kind, thumb != nil, w, h)
	}

	kind, _, thumb, _, _ = classifyClip("image/png", []byte("not a png"))
	if kind != "binary" || thumb != nil {
		t.Errorf("undecodable image classify = (%q, thumb=%v), want (binary, false)", kind, thumb != nil)
	}

	if kind, _, _, _, _ := classifyClip("application/pdf", []byte("%PDF")); kind != "binary" {
		t.Errorf("pdf classify = %q, want binary", kind)
	}
}

// pickBestMime reproduces the reference priority: text types, then image types,
// then the first offered.
func TestPickBestMime(t *testing.T) {
	cases := []struct {
		offered []string
		want    string
	}{
		{[]string{"text/html", "text/plain", "text/plain;charset=utf-8"}, "text/plain;charset=utf-8"},
		{[]string{"text/html", "text/plain"}, "text/plain"},
		{[]string{"image/bmp", "STRING", "TEXT"}, "STRING"},
		{[]string{"image/bmp", "image/png"}, "image/png"},
		{[]string{"image/tiff", "image/jpeg"}, "image/jpeg"},
		{[]string{"application/x-thing"}, "application/x-thing"},
		{nil, ""},
	}
	for _, c := range cases {
		if got := pickBestMime(c.offered); got != c.want {
			t.Errorf("pickBestMime(%v) = %q, want %q", c.offered, got, c.want)
		}
	}
}

// Empty data is dropped, and a selection past the entry cap is truncated.
func TestClipIngestSizeRules(t *testing.T) {
	s := &clipState{}
	s.ingest("text/plain", nil)
	s.ingest("text/plain", []byte{})
	if len(s.entries) != 0 {
		t.Fatalf("empty selection stored: %d entries", len(s.entries))
	}

	s.ingest("text/plain", bytes.Repeat([]byte("a"), clipMaxEntryBytes+100))
	if len(s.entries) != 1 {
		t.Fatalf("entries = %d, want 1", len(s.entries))
	}
	if s.entries[0].Size != clipMaxEntryBytes {
		t.Errorf("stored size = %d, want %d (truncated at the 10 MiB cap)", s.entries[0].Size, clipMaxEntryBytes)
	}
}

func TestTruncateRunes(t *testing.T) {
	if got := truncateRunes("héllo", 3); got != "hél" {
		t.Errorf("truncateRunes(héllo, 3) = %q, want hél", got)
	}
	if got := truncateRunes("hi", 5); got != "hi" {
		t.Errorf("truncateRunes(hi, 5) = %q, want hi", got)
	}
}

// The history survives a daemon restart: ingested entries are written to the
// state dir and a fresh clipState.load() restores them, order, bytes and nextID.
func TestClipPersistence(t *testing.T) {
	dir := t.TempDir()
	dataDir := filepath.Join(dir, "data")
	if err := os.MkdirAll(dataDir, 0o700); err != nil {
		t.Fatal(err)
	}
	cache := t.TempDir()
	s := &clipState{stateDir: dir, dataDir: dataDir, cacheDir: cache}
	s.ingest("text/plain", []byte("hello"))
	s.ingest("text/plain", []byte("world"))

	s2 := &clipState{stateDir: dir, dataDir: dataDir, cacheDir: cache}
	s2.load()
	if len(s2.entries) != 2 {
		t.Fatalf("reloaded %d entries, want 2", len(s2.entries))
	}
	if s2.entries[0].Preview != "world" {
		t.Errorf("front after reload = %q, want %q", s2.entries[0].Preview, "world")
	}
	if !bytes.Equal(s2.entries[0].data, []byte("world")) {
		t.Errorf("reloaded front bytes = %q, want %q", s2.entries[0].data, "world")
	}
	if s2.nextID != s.nextID {
		t.Errorf("reloaded nextID = %d, want %d", s2.nextID, s.nextID)
	}
}

// isClipWatcherCmdline must match only our own watcher/helper -- never another
// app's wl-paste or the daemon itself -- since a false match SIGKILLs the pid.
func TestIsClipWatcherCmdline(t *testing.T) {
	const self = "/home/u/.local/bin/ryoku-shell"
	cases := []struct {
		name string
		argv []string
		want bool
	}{
		{"watcher", []string{"wl-paste", "--watch", self, "__clip-ingest"}, true},
		{"helper", []string{self, "__clip-ingest"}, true},
		{"other-app wl-paste", []string{"wl-paste", "--watch", "/usr/bin/cliphist", "store"}, false},
		{"plain wl-paste", []string{"wl-paste", "-n", "-t", "image/png"}, false},
		{"our daemon", []string{self, "daemon"}, false},
		{"our other verb", []string{self, "ipc", "menu"}, false},
		{"ingest marker, foreign binary", []string{"wl-paste", "--watch", "/other/bin", "__clip-ingest"}, false},
		{"empty", nil, false},
	}
	for _, c := range cases {
		if got := isClipWatcherCmdline(c.argv, self); got != c.want {
			t.Errorf("%s: isClipWatcherCmdline(%v) = %v, want %v", c.name, c.argv, got, c.want)
		}
	}
}
