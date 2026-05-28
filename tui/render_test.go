package main

import (
	"strings"
	"testing"

	tea "charm.land/bubbletea/v2"
)

func TestMenuRenders(t *testing.T) {
	var mm tea.Model = newModel()
	mm, _ = mm.Update(tea.WindowSizeMsg{Width: 120, Height: 40})
	v := mm.(model).View()
	for _, s := range []string{"R Y O K U", "system control center", "Update", "Doctor", "Recovery", "Logs", "Manage packages", "channel"} {
		if !strings.Contains(v.Content, s) {
			t.Errorf("menu view missing %q", s)
		}
	}
	if !v.AltScreen {
		t.Error("expected AltScreen=true")
	}
}

func TestResultsRendersSweep(t *testing.T) {
	var mm tea.Model = newModel()
	mm, _ = mm.Update(tea.WindowSizeMsg{Width: 120, Height: 40})
	m := mm.(model)
	m.state = stateRunning
	m.runState = runActive
	m.active = m.items[0]
	m.animating = true
	m.appendLine("hello from the engine")
	out := m.View().Content
	if !strings.Contains(out, "Update") || !strings.Contains(out, "hello from the engine") {
		t.Errorf("results view missing title or streamed line:\n%s", out)
	}
}
