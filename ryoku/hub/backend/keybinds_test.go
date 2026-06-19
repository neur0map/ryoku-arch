package main

import (
	"strings"
	"testing"
)

// A representative slice of binds.lua exercising every parser branch: a header,
// a modified combo, a comment vs a derived description, a string-literal media
// key, a mouse bind, and the 1..0 workspace loop.
const sampleBinds = `local mod = "SUPER"

-- Windows
hl.bind(mod .. " + Q",         hl.dsp.window.close())                           -- close active window
hl.bind(mod .. " + SHIFT + A", hl.dsp.window.float({ action = "disable" }))     -- restore: tile it back to normal

-- Apps
hl.bind(mod .. " + Return",    hl.dsp.exec_cmd("kitty"))
hl.bind(mod .. " + N",         hl.dsp.exec_cmd("kitty -e nvim"))                -- neovim

-- Switch workspaces
hl.bind(mod .. " + Left",       hl.dsp.focus({ workspace = "r-1" }))
for i = 1, 10 do
    local key = i % 10 -- 10 maps to the 0 key
    hl.bind(mod .. " + " .. key,          hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key,  hl.dsp.window.move({ workspace = i }))
end

-- Media and volume keys
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
`

func find(l legend, cat string) *category {
	for i := range l.Categories {
		if l.Categories[i].Name == cat {
			return &l.Categories[i]
		}
	}
	return nil
}

func TestParseCategories(t *testing.T) {
	l := parseBinds(sampleBinds)
	want := []string{"Windows", "Apps", "Switch workspaces", "Media and volume keys"}
	if len(l.Categories) != len(want) {
		t.Fatalf("got %d categories, want %d: %+v", len(l.Categories), len(want), l.Categories)
	}
	for i, n := range want {
		if l.Categories[i].Name != n {
			t.Errorf("category %d = %q, want %q", i, l.Categories[i].Name, n)
		}
	}
}

func TestModifiedComboKeys(t *testing.T) {
	w := find(parseBinds(sampleBinds), "Windows")
	if w == nil || len(w.Binds) != 2 {
		t.Fatalf("Windows category malformed: %+v", w)
	}
	got := strings.Join(w.Binds[1].Keys, "|")
	if got != "Super|Shift|A" {
		t.Errorf("keys = %q, want Super|Shift|A", got)
	}
	if w.Binds[0].Desc != "Close active window" {
		t.Errorf("desc = %q, want capitalized comment", w.Binds[0].Desc)
	}
}

func TestDerivedDescriptionFromDispatcher(t *testing.T) {
	a := find(parseBinds(sampleBinds), "Apps")
	if a == nil || len(a.Binds) == 0 {
		t.Fatal("Apps category missing")
	}
	// kitty has no trailing comment, so the description comes from the dispatcher.
	if a.Binds[0].Desc != "Terminal" {
		t.Errorf("derived desc = %q, want Terminal", a.Binds[0].Desc)
	}
}

func TestWorkspaceLoopCollapses(t *testing.T) {
	ws := find(parseBinds(sampleBinds), "Switch workspaces")
	if ws == nil {
		t.Fatal("Switch workspaces category missing")
	}
	// One explicit Left bind plus the two loop binds = three entries.
	if len(ws.Binds) != 3 {
		t.Fatalf("got %d binds, want 3: %+v", len(ws.Binds), ws.Binds)
	}
	focus := ws.Binds[1]
	if strings.Join(focus.Keys, "|") != "Super|1\u20260" {
		t.Errorf("loop keys = %q, want Super|1…0", strings.Join(focus.Keys, "|"))
	}
	if focus.Desc != "Focus workspace" {
		t.Errorf("loop desc = %q, want Focus workspace", focus.Desc)
	}
	if ws.Binds[2].Desc != "Move window to workspace" {
		t.Errorf("loop move desc = %q", ws.Binds[2].Desc)
	}
}

func TestMediaKeyLiteral(t *testing.T) {
	m := find(parseBinds(sampleBinds), "Media and volume keys")
	if m == nil || len(m.Binds) != 1 {
		t.Fatalf("media category malformed: %+v", m)
	}
	if strings.Join(m.Binds[0].Keys, "|") != "Vol +" {
		t.Errorf("media key = %q, want 'Vol +'", strings.Join(m.Binds[0].Keys, "|"))
	}
	if m.Binds[0].Desc != "Volume up" {
		t.Errorf("media desc = %q, want Volume up", m.Binds[0].Desc)
	}
}
