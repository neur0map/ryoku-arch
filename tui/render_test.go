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

func TestFinishedRunStatus(t *testing.T) {
	var mm tea.Model = newModel()
	mm, _ = mm.Update(tea.WindowSizeMsg{Width: 120, Height: 40})
	m := mm.(model)
	m.state = stateFinished
	m.finished = finishedRun
	m.active = m.items[0]
	m.exitCode = 0
	if !strings.Contains(m.View().Content, "Update complete") {
		t.Error("run-complete status missing")
	}
	m.exitCode = 7
	if !strings.Contains(m.View().Content, "exit 7") {
		t.Error("run-failure exit code missing")
	}
}
