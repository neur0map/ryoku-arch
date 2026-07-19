package main

import (
	"strings"
	"testing"
)

// slice of binds.lua hitting every parser branch: a header, a modified combo,
// comment vs derived description, a string-literal media key, a mouse bind,
// and the 1..0 workspace loop.
const sampleBinds = `local mod = "SUPER"
local function K(k) return k end

-- Windows
hl.bind(K(mod .. " + Q"),         hl.dsp.window.close())                           -- close active window
hl.bind(K(mod .. " + SHIFT + A"), hl.dsp.window.float({ action = "disable" }))     -- restore: tile it back to normal

-- Apps
hl.bind(K(mod .. " + Return"),    hl.dsp.exec_cmd("kitty"))
hl.bind(K(mod .. " + N"),         hl.dsp.exec_cmd("kitty -e nvim"))                -- neovim

-- Switch workspaces
hl.bind(K(mod .. " + Left"),       hl.dsp.focus({ workspace = "r-1" }))
for i = 1, 10 do
    local key = i % 10 -- 10 maps to the 0 key
    hl.bind(K(mod .. " + " .. key),          hl.dsp.focus({ workspace = i }))
    hl.bind(K(mod .. " + SHIFT + " .. key),  hl.dsp.window.move({ workspace = i }))
end

-- Media and volume keys
hl.bind(K("XF86AudioRaiseVolume"), hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
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
	// kitty has no trailing comment; description comes from the dispatcher.
	if a.Binds[0].Desc != "Terminal" {
		t.Errorf("derived desc = %q, want Terminal", a.Binds[0].Desc)
	}
}

func TestWorkspaceLoopCollapses(t *testing.T) {
	ws := find(parseBinds(sampleBinds), "Switch workspaces")
	if ws == nil {
		t.Fatal("Switch workspaces category missing")
	}
	// 1 explicit Left bind + 2 loop binds = 3 entries.
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

func TestPrettyKeyGrave(t *testing.T) {
	if got := prettyKey("grave"); got != "`" {
		t.Errorf("grave key = %q, want backtick", got)
	}
}

// lambda action (multi-dispatch, e.g. SUPER+A float + centre) isn't an
// hl.dsp expression but it still belongs in the legend. description comes
// from the trailing comment.
func TestLambdaBind(t *testing.T) {
	const src = `-- Windows
hl.bind(mod .. " + A", function() hl.dispatch(hl.dsp.window.float({ action = "toggle" })); hl.dispatch(hl.dsp.window.center()) end) -- float + centre the window
`
	w := find(parseBinds(src), "Windows")
	if w == nil || len(w.Binds) != 1 {
		t.Fatalf("Windows category malformed: %+v", w)
	}
	if got := strings.Join(w.Binds[0].Keys, "|"); got != "Super|A" {
		t.Errorf("keys = %q, want Super|A", got)
	}
	if w.Binds[0].Desc != "Float + centre the window" {
		t.Errorf("desc = %q, want comment-derived description", w.Binds[0].Desc)
	}
}

// K() (the rebind helper) is unwrapped so the raw combo -- the rebind id K() keys
// on at runtime -- is captured, and a single literal chord is rebindable while the
// workspace-loop range and pointer binds are not.
func TestComboAndRebindable(t *testing.T) {
	l := parseBinds(sampleBinds)
	w := find(l, "Windows")
	if w == nil || len(w.Binds) < 1 {
		t.Fatal("Windows category missing")
	}
	if w.Binds[0].Combo != "SUPER + Q" {
		t.Errorf("combo = %q, want SUPER + Q", w.Binds[0].Combo)
	}
	if !w.Binds[0].Rebindable {
		t.Error("SUPER + Q should be rebindable")
	}
	ws := find(l, "Switch workspaces")
	loop := ws.Binds[len(ws.Binds)-1]
	if loop.Rebindable {
		t.Errorf("loop bind %q should not be rebindable", loop.Combo)
	}
	m := find(l, "Media and volume keys")
	if m.Binds[0].Combo != "XF86AudioRaiseVolume" || !m.Binds[0].Rebindable {
		t.Errorf("media combo=%q rebindable=%v", m.Binds[0].Combo, m.Binds[0].Rebindable)
	}
	mouse := parseBinds("-- M\nhl.bind(K(mod .. \" + mouse:272\"), hl.dsp.window.drag(), { mouse = true })\n")
	if mouse.Categories[0].Binds[0].Rebindable {
		t.Error("mouse bind should not be rebindable")
	}
}

func TestDescribeRyokuApp(t *testing.T) {
	if got := describeExec("ryoku-app browser"); got != "browser" {
		t.Errorf("describeExec ryoku-app = %q, want browser", got)
	}
}
