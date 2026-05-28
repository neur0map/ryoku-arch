package main

import (
	"fmt"
	"os"
	"strings"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

// runConfirm renders a branded yes/no prompt and exits 0 (yes) or 1 (no). It is
// the gum-free replacement for `gum confirm`.
//
//	ryoku-tui confirm [--default=yes|no] "Prompt text"
func runConfirm(args []string) int {
	def := false
	var prompt string
	for _, a := range args {
		switch {
		case a == "--default=yes" || a == "--default=true" || a == "--default":
			def = true
		case a == "--default=no" || a == "--default=false":
			def = false
		case strings.HasPrefix(a, "--"):
			// ignore unknown flags
		default:
			prompt = a
		}
	}
	if prompt == "" {
		prompt = "Continue?"
	}

	if !isTTY() {
		if def {
			return 0
		}
		return 1
	}

	m := confirmModel{prompt: prompt, yes: def}
	res, err := tea.NewProgram(m).Run()
	if err != nil {
		if def {
			return 0
		}
		return 1
	}
	if cm, ok := res.(confirmModel); ok && cm.confirmed {
		return 0
	}
	return 1
}

func isTTY() bool {
	fi, err := os.Stdin.Stat()
	if err != nil {
		return false
	}
	return (fi.Mode() & os.ModeCharDevice) != 0
}

type confirmModel struct {
	prompt    string
	yes       bool
	confirmed bool
	done      bool
}

func (m confirmModel) Init() tea.Cmd { return nil }

func (m confirmModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := msg.(tea.KeyPressMsg); ok {
		switch key.String() {
		case "left", "right", "tab", "h", "l":
			m.yes = !m.yes
		case "y", "Y":
			m.yes, m.confirmed, m.done = true, true, true
			return m, tea.Quit
		case "n", "N":
			m.yes, m.confirmed, m.done = false, false, true
			return m, tea.Quit
		case "enter":
			m.confirmed = m.yes
			m.done = true
			return m, tea.Quit
		case "esc", "ctrl+c", "q":
			m.confirmed = false
			m.done = true
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m confirmModel) View() tea.View {
	if m.done {
		return tea.NewView("")
	}
	brand := styBrand.Render("力  Ryoku")
	q := lipgloss.NewStyle().Foreground(colFg).Render(m.prompt)

	yes := "  Yes  "
	no := "  No  "
	selOn := lipgloss.NewStyle().Background(colAccent).Foreground(lipgloss.Color("#1a1a2e")).Bold(true)
	selOff := lipgloss.NewStyle().Foreground(colMuted2)
	if m.yes {
		yes = selOn.Render(yes)
		no = selOff.Render(no)
	} else {
		yes = selOff.Render(yes)
		no = selOn.Render(no)
	}

	box := styHeaderBox.Render(lipgloss.JoinVertical(lipgloss.Left,
		brand+"  "+q,
		"",
		yes+"   "+no,
	))
	hint := styHint.Render("←/→ choose   enter confirm   y/n   esc cancel")
	return tea.NewView(fmt.Sprintf("\n%s\n %s\n", box, hint))
}
