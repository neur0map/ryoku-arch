// ryoku-tui - the unified Ryoku control center.
//
// A bubbletea v2 / lipgloss v2 front-end composed as ONE contained, fixed-width
// card (the soft-serve / k9s style): a single accent colour, achromatic
// everything-else, aligned columns, a full-row selection bar, and explicit
// truncation so nothing wraps inside the border. Selection happens here; for
// Update / Doctor / Recovery the TUI hands the terminal to the underlying bash
// engine via tea.ExecProcess so those tools render their own full-fidelity,
// real-time output (ryoku-update's scroll-region dashboard, live pacman, etc.).
package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

type viewState int

const (
	stateMenu viewState = iota
	stateFinished
)

type finishedKind int

const (
	finishedRun finishedKind = iota
	finishedLogs
)

// runState drives the status glyph (stateGlyph in theme.go).
type runState int

const (
	runIdle runState = iota
	runActive
	runOK
	runFail
)

type menuItem struct {
	key   string
	title string
	desc  string
}

type execDoneMsg struct {
	item    menuItem
	code    int
	logPath string // captured log for this run ("" if none)
}

type updateCheckMsg struct {
	available bool
	behind    int
}

type model struct {
	width, height int

	state  viewState
	cursor int
	items  []menuItem

	channel string
	version string

	// viewport is used only for the Logs view (a static file).
	vp       viewport.Model
	vpReady  bool
	logLines []string

	active   menuItem
	finished finishedKind
	exitCode int
	lastLog  string // path to the most recent run's captured log

	note string

	// "new version available" banner, filled in by a background check at start.
	updateAvailable bool
	updateBehind    int

	// execAfter, when set, is an external TUI (gpk) to run on the released
	// terminal after the program quits; main() then re-opens the menu. This
	// avoids nesting one bubbletea program inside another via ExecProcess,
	// which does not hand the terminal over cleanly.
	execAfter string
}

func newModel() model {
	items := []menuItem{
		{"update", "Update", "update Ryoku and all system packages"},
		{"doctor", "Doctor", "check system health and repair issues"},
		{"recovery", "Recovery", "emergency MedEvac: rebuild the install"},
		{"logs", "Logs", "view the most recent update log"},
		{"packages", "Packages", "open the graphical package manager"},
	}
	return model{
		state:   stateMenu,
		items:   items,
		channel: detectChannel(),
		version: detectVersion(),
	}
}

func (m model) Init() tea.Cmd {
	// Background check (non-blocking): is a newer version on the channel?
	return func() tea.Msg {
		a, n := checkUpdateAvailable()
		return updateCheckMsg{available: a, behind: n}
	}
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.layoutViewport()
		return m, nil

	case tea.KeyPressMsg:
		return m.handleKey(msg)

	case execDoneMsg:
		m.active = msg.item
		m.exitCode = msg.code
		m.lastLog = msg.logPath
		m.finished = finishedRun
		m.state = stateFinished
		return m, nil

	case updateCheckMsg:
		m.updateAvailable = msg.available
		m.updateBehind = msg.behind
		return m, nil
	}
	return m, nil
}

func (m model) handleKey(msg tea.KeyPressMsg) (tea.Model, tea.Cmd) {
	switch m.state {
	case stateMenu:
		switch msg.String() {
		case "q", "ctrl+c", "esc":
			return m, tea.Quit
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.items)-1 {
				m.cursor++
			}
		case "enter", " ":
			return m.selectItem(m.items[m.cursor])
		}
		return m, nil

	case stateFinished:
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "enter", "esc", "backspace":
			m.state = stateMenu
			m.note = ""
			m.logLines = nil
			return m, nil
		}
		if m.finished == finishedLogs && m.vpReady {
			var cmd tea.Cmd
			m.vp, cmd = m.vp.Update(msg)
			return m, cmd
		}
		return m, nil
	}
	return m, nil
}

func (m model) selectItem(it menuItem) (tea.Model, tea.Cmd) {
	switch it.key {
	case "packages":
		// gpk is its own full-screen TUI; quit so main() can run it on a
		// cleanly-released terminal, then re-open this menu. (Nesting it inside
		// tea.ExecProcess does not hand the terminal over cleanly.)
		m.execAfter = "gpk"
		return m, tea.Quit
	case "logs":
		m.active = it
		// Show the most recent run's log (doctor/recovery/update); fall back to
		// the update log when nothing has run yet this session.
		raw := readLogFile(m.lastLog)
		m.logLines = make([]string, len(raw))
		for i, line := range raw {
			m.logLines[i] = applyLineStyle(line)
		}
		m.finished = finishedLogs
		m.state = stateFinished
		m.layoutViewport()
		m.refreshViewport()
		return m, nil
	}

	// Update / Doctor / Recovery / Packages: hand the terminal to the engine
	// (which prompts for sudo once, on the real terminal, and renders its own
	// full output).
	m.active = it
	m.note = ""
	return m, m.execEngine(it)
}

func (m model) execEngine(it menuItem) tea.Cmd {
	name, args, env := commandFor(it)
	logPath := ""
	var c *exec.Cmd
	switch it.key {
	case "packages":
		c = exec.Command(name, args...) // gpk is an interactive TUI; no log
	case "update":
		c = exec.Command(name, args...) // ryoku-update logs itself to update.log
		logPath = updateLogPath()
	default: // doctor, recovery: tee through `script` so the run is reviewable
		logPath = ensureRunLog(it.key)
		cmdline := name
		for _, a := range args {
			cmdline += " " + a
		}
		c = exec.Command("script", "-q", "-f", "-e", "-c", cmdline, logPath)
	}
	c.Env = append(os.Environ(), env...)
	return tea.ExecProcess(c, func(err error) tea.Msg {
		code := 0
		if err != nil {
			if ee, ok := err.(*exec.ExitError); ok {
				code = ee.ExitCode()
			} else {
				code = 1
			}
		}
		return execDoneMsg{item: it, code: code, logPath: logPath}
	})
}

// ----- view: one contained card -----

func (m model) View() tea.View {
	var body string
	if m.state == stateFinished && m.finished == finishedLogs {
		body = m.logsView()
	} else {
		card := styCard.Render(strings.Join(m.cardLines(), "\n"))
		// "new version available" pill sits on top of the box, on the menu.
		if m.state == stateMenu && m.updateAvailable {
			banner := styUpdateBanner.Render(m.updateBannerText())
			card = lipgloss.JoinVertical(lipgloss.Center, banner, "", card)
		}
		if m.width > 0 && m.height > 0 {
			body = lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Center, card)
		} else {
			body = card
		}
	}
	v := tea.NewView(body)
	v.AltScreen = true
	return v
}

func (m model) updateBannerText() string {
	if m.updateBehind > 0 {
		return fmt.Sprintf("↑ new version available  ·  %d behind  ·  run Update", m.updateBehind)
	}
	return "↑ new version available  ·  run Update"
}

// cardLines builds the inner lines of the card; each is exactly cardLineW wide.
func (m model) cardLines() []string {
	lines := []string{
		centerLine(styBrand.Render("力  R Y O K U")),
		centerLine(stySubtitle.Render("system control center")),
		"",
		centerLine(styMeta.Render(m.channel + "   ·   " + m.version)),
		divider(),
		"",
	}
	if m.state == stateMenu {
		lines = append(lines, m.menuRows()...)
		lines = append(lines, "", divider())
		if m.note != "" {
			lines = append(lines, leftLine("  "+m.note))
		}
		lines = append(lines, leftLine("  "+styHint.Render("↑/↓ move    enter select    q quit")))
	} else {
		lines = append(lines, m.finishedLines()...)
	}
	return lines
}

func (m model) menuRows() []string {
	const titleW = 10
	descBudget := cardLineW - 4 - titleW - 1 // indent/arrow(4) + title + gap(1)
	rows := make([]string, len(m.items))
	for i, it := range m.items {
		title := fmt.Sprintf("%-*s", titleW, it.title)
		desc := truncate(it.desc, descBudget)
		if i == m.cursor {
			// Full-width accent selection bar (one uniform style, no nesting).
			plain := "  ▸ " + title + " " + desc
			rows[i] = styRowSel.Foreground(colSelFg).Bold(true).Width(cardLineW).Render(plain)
		} else {
			rows[i] = leftLine("    " + styItemTitle.Render(title) + " " + styItemDesc.Render(desc))
		}
	}
	return rows
}

func (m model) finishedLines() []string {
	var status string
	if m.exitCode == 0 {
		status = stateGlyph(runOK) + " " + styOK.Render(m.active.title+" complete")
	} else {
		status = stateGlyph(runFail) + " " + styErr.Render(fmt.Sprintf("%s failed   exit %d", m.active.title, m.exitCode))
	}
	return []string{
		centerLine(status),
		"",
		centerLine(styHint.Render("the full output scrolled above")),
		centerLine(styHint.Render("choose Logs to review it")),
		"",
		divider(),
		centerLine(styHint.Render("enter  back to menu       q  quit")),
	}
}

// logsView is a separate, top-anchored layout: a brand line over a bordered,
// scrollable viewport of the saved log.
func (m model) logsView() string {
	title := styBrand.Render("力  R Y O K U") + "  " + stySubtitle.Render("update log")
	hint := styHint.Render("enter  back to menu       q  quit       ↑/↓  scroll")
	var pane string
	if m.vpReady {
		pane = styPaneBorder.Render(m.vp.View())
	}
	block := lipgloss.JoinVertical(lipgloss.Center, title, "", pane, "", hint)
	if m.width > 0 && m.height > 0 {
		return lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Top, block)
	}
	return block
}

// ----- viewport (Logs only) -----

func (m *model) layoutViewport() {
	if m.width == 0 || m.height == 0 {
		return
	}
	vpW := cardLineW + 6
	if vpW > m.width-4 {
		vpW = m.width - 4
	}
	if vpW < 20 {
		vpW = 20
	}
	vpH := m.height - 8
	if vpH < 4 {
		vpH = 4
	}
	if !m.vpReady {
		m.vp = viewport.New(viewport.WithWidth(vpW), viewport.WithHeight(vpH))
		m.vpReady = true
	} else {
		m.vp.SetWidth(vpW)
		m.vp.SetHeight(vpH)
	}
}

func (m *model) refreshViewport() {
	if !m.vpReady {
		m.layoutViewport()
	}
	if !m.vpReady {
		return
	}
	m.vp.SetContent(strings.Join(m.logLines, "\n"))
	m.vp.GotoBottom()
}

// applyLineStyle highlights common log prefixes in the loaded log so the Logs
// view reads at a glance instead of being a wall of plain text.
func applyLineStyle(s string) string {
	trim := strings.TrimLeft(s, " \t")
	switch {
	case strings.HasPrefix(trim, "ERROR:"),
		strings.HasPrefix(trim, "ERR:"),
		strings.HasPrefix(trim, "FAIL "),
		strings.HasPrefix(trim, "FAIL:"),
		strings.HasPrefix(trim, "✗"):
		return styErr.Render(s)
	case strings.HasPrefix(trim, "WARN "),
		strings.HasPrefix(trim, "WARN:"),
		strings.HasPrefix(trim, "WARNING:"),
		strings.HasPrefix(trim, "Warning:"):
		return styWarn.Render(s)
	case strings.HasPrefix(trim, "OK:"),
		strings.HasPrefix(trim, "OK "),
		strings.HasPrefix(trim, "FIX "),
		strings.HasPrefix(trim, "FIX:"),
		strings.HasPrefix(trim, "✓"):
		return styOK.Render(s)
	case strings.HasPrefix(trim, "==>"),
		strings.HasPrefix(trim, "INFO:"),
		strings.HasPrefix(trim, "INFO "),
		strings.HasPrefix(trim, "::"):
		return styPaneTitle.Render(s)
	case strings.HasPrefix(trim, "["):
		return styPaneTitle.Render(s)
	}
	return s
}

func main() {
	if len(os.Args) > 1 {
		switch os.Args[1] {
		case "confirm":
			os.Exit(runConfirm(os.Args[2:]))
		case "style":
			os.Exit(runStyle(os.Args[2:]))
		case "choose":
			os.Exit(runChoose(os.Args[2:]))
		case "input":
			os.Exit(runInput(os.Args[2:]))
		case "filter":
			os.Exit(runFilter(os.Args[2:]))
		case "spin":
			os.Exit(runSpin(os.Args[2:]))
		}
	}

	// Control-center loop: show the menu; if the user picks an external TUI
	// (gpk), the model quits with execAfter set, we run that program on the
	// now-released terminal, then loop back to a fresh menu. A normal quit
	// (execAfter empty) breaks the loop.
	for {
		fm, err := tea.NewProgram(newModel()).Run()
		if err != nil {
			fmt.Fprintln(os.Stderr, "ryoku-tui:", err)
			os.Exit(1)
		}
		final, ok := fm.(model)
		if !ok || final.execAfter == "" {
			return
		}
		c := exec.Command(final.execAfter)
		c.Stdin, c.Stdout, c.Stderr = os.Stdin, os.Stdout, os.Stderr
		_ = c.Run()
	}
}
