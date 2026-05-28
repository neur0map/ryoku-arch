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

func TestSudoPromptMasksPassword(t *testing.T) {
	var mm tea.Model = newModel()
	mm, _ = mm.Update(tea.WindowSizeMsg{Width: 120, Height: 40})
	m := mm.(model)
	m.state = stateSudoPrompt
	m.sudoFor = m.items[0]
	m.sudoPasswd = "hunter2"
	out := m.View().Content
	if strings.Contains(out, "hunter2") {
		t.Error("password leaked into view")
	}
	if !strings.Contains(out, strings.Repeat("•", 7)) {
		t.Error("password not masked")
	}
	if !strings.Contains(out, "Sudo password required") {
		t.Error("sudo prompt title missing")
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
