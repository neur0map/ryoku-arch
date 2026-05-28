// ryoku-tui - the unified Ryoku control center.
//
// A bubbletea v2 / lipgloss v2 front-end: a fixed branded header (with a
// harmonica-driven activity sweep) over a menu of actions. Selection happens
// in the TUI; for Update / Doctor / Recovery the TUI HANDS THE TERMINAL to the
// underlying bash engine via tea.ExecProcess, so those tools render their own
// full-fidelity, real-time output (ryoku-update's scroll-region dashboard with
// the RYOKU ascii art, pacman's live colour/progress, etc.) instead of being
// captured and re-rendered. Logs and the sudo password prompt stay in the TUI.
package main

import (
	"fmt"
	"math"
	"os"
	"os/exec"
	"strings"
	"time"

	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
	"github.com/charmbracelet/harmonica"
)

type viewState int

const (
	stateMenu viewState = iota
	stateSudoPrompt
	stateFinished
)

// what the finished screen is showing
type finishedKind int

const (
	finishedRun  finishedKind = iota // post-run status of an ExecProcess action
	finishedLogs                     // the loaded update log in the viewport
)

// runState drives the status glyph (stateGlyph in theme.go).
type runState int

const (
	runIdle runState = iota
	runActive
	runOK
	runFail
)

const animFPS = 60

type menuItem struct {
	key       string
	title     string
	desc      string
	needsSudo bool
	detached  bool
}

// ----- messages -----

type animTickMsg time.Time
type sudoAuthResultMsg struct {
	item menuItem
	ok   bool
	err  string
}
type execDoneMsg struct {
	item menuItem
	code int
}

type model struct {
	width, height int

	state  viewState
	cursor int
	items  []menuItem

	channel string
	version string

	// viewport is used only for the Logs view (a static file), never for
	// capturing live command output.
	vp      viewport.Model
	vpReady bool
	logLines []string

	active   menuItem
	finished finishedKind
	exitCode int

	note string

	// in-TUI sudo prompt
	sudoFor    menuItem
	sudoPasswd string
	sudoError  string

	// persistent harmonica sweep shown in the header (always animating)
	spring   harmonica.Spring
	sweepPos float64
	sweepVel float64
	sweepTo  float64
}

func newModel() model {
	items := []menuItem{
		{key: "update", title: "Update", desc: "fetch and apply the latest Ryoku + system packages", needsSudo: true},
		{key: "doctor", title: "Doctor", desc: "check system health and repair common problems", needsSudo: true},
		{key: "recovery", title: "Recovery", desc: "emergency MedEvac: rebuild a coherent install", needsSudo: true},
		{key: "logs", title: "Logs", desc: "view the most recent update log"},
		{key: "packages", title: "Manage packages", desc: "open the graphical package manager (gpk)", detached: true},
	}
	return model{
		state:   stateMenu,
		items:   items,
		channel: detectChannel(),
		version: detectVersion(),
		// gentle, smooth ease (low frequency, heavy damping)
		spring: harmonica.NewSpring(harmonica.FPS(animFPS), 4.0, 0.75),
	}
}

func (m model) Init() tea.Cmd {
	return animTick()
}

func animTick() tea.Cmd {
	return tea.Tick(time.Second/animFPS, func(t time.Time) tea.Msg {
		return animTickMsg(t)
	})
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.sweepTo = float64(m.sweepWidth())
		m.layoutViewport()
		return m, nil

	case tea.KeyPressMsg:
		return m.handleKey(msg)

	case animTickMsg:
		// The header sweep runs forever, so there is always a little life.
		m.sweepPos, m.sweepVel = m.spring.Update(m.sweepPos, m.sweepVel, m.sweepTo)
		if math.Abs(m.sweepPos-m.sweepTo) < 0.6 && math.Abs(m.sweepVel) < 0.6 {
			if m.sweepTo == 0 {
				m.sweepTo = float64(m.sweepWidth())
			} else {
				m.sweepTo = 0
			}
		}
		return m, animTick()

	case sudoAuthResultMsg:
		if !msg.ok {
			m.sudoError = msg.err
			return m, nil
		}
		m.sudoFor = menuItem{}
		m.sudoError = ""
		return m, m.execEngine(msg.item)

	case execDoneMsg:
		m.active = msg.item
		m.exitCode = msg.code
		m.finished = finishedRun
		m.state = stateFinished
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

	case stateSudoPrompt:
		switch msg.String() {
		case "esc":
			m.sudoPasswd = ""
			m.sudoError = ""
			m.sudoFor = menuItem{}
			m.state = stateMenu
			return m, nil
		case "ctrl+c":
			m.sudoPasswd = ""
			return m, tea.Quit
		case "enter":
			passwd := m.sudoPasswd
			m.sudoPasswd = ""
			m.sudoError = ""
			return m, trySudoAuth(m.sudoFor, passwd)
		case "backspace":
			r := []rune(m.sudoPasswd)
			if len(r) > 0 {
				m.sudoPasswd = string(r[:len(r)-1])
			}
			return m, nil
		case "ctrl+u":
			m.sudoPasswd = ""
			return m, nil
		default:
			if t := msg.Text; t != "" {
				m.sudoPasswd += t
			}
			return m, nil
		}

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
		if err := launchDetached("gpk"); err != nil {
			m.note = styErr.Render("could not launch gpk: " + err.Error())
		} else {
			m.note = styOK.Render("opened the package manager (gpk)")
		}
		return m, nil
	case "logs":
		m.active = it
		raw := readLog()
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

	// Update / Doctor / Recovery: authenticate (in-TUI) if needed, then hand
	// the terminal to the bash engine.
	m.active = it
	m.note = ""
	if it.needsSudo && !sudoCached() {
		m.sudoFor = it
		m.sudoPasswd = ""
		m.sudoError = ""
		m.state = stateSudoPrompt
		return m, nil
	}
	return m, m.execEngine(it)
}

// execEngine hands the whole terminal to the bash engine (tea.ExecProcess), so
// it renders its own full-fidelity live output, then reports the exit code.
func (m model) execEngine(it menuItem) tea.Cmd {
	name, args, env := commandFor(it)
	c := exec.Command(name, args...)
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
		return execDoneMsg{item: it, code: code}
	})
}

// trySudoAuth runs `sudo -S -v` with the supplied password on stdin. The
// password lives only inside this closure for the duration of the call.
func trySudoAuth(it menuItem, password string) tea.Cmd {
	return func() tea.Msg {
		c := exec.Command("sudo", "-S", "-p", "", "-v")
		c.Stdin = strings.NewReader(password + "\n")
		var stderr strings.Builder
		c.Stderr = &stderr
		if err := c.Run(); err == nil {
			return sudoAuthResultMsg{item: it, ok: true}
		}
		msg := "authentication failed"
		errOut := stderr.String()
		switch {
		case strings.Contains(errOut, "Sorry, try again") || strings.Contains(errOut, "incorrect password"):
			msg = "incorrect password"
		case strings.Contains(errOut, "not allowed"):
			msg = "this user is not allowed to run sudo"
		}
		return sudoAuthResultMsg{item: it, ok: false, err: msg}
	}
}

// ----- view -----

func (m model) View() tea.View {
	header := m.renderHeader()
	var body string
	switch m.state {
	case stateMenu:
		body = lipgloss.JoinVertical(lipgloss.Left, header, m.renderMenu())
	case stateSudoPrompt:
		body = lipgloss.JoinVertical(lipgloss.Left, header, m.renderSudoPrompt())
	case stateFinished:
		body = lipgloss.JoinVertical(lipgloss.Left, header, m.renderFinished())
	}
	if m.width > 0 && m.height > 0 {
		body = lipgloss.Place(m.width, m.height, lipgloss.Center, lipgloss.Top, body)
	}
	v := tea.NewView(body)
	v.AltScreen = true
	return v
}

func (m model) renderHeader() string {
	brand := styBrand.Render("力  R Y O K U")
	sub := stySubtitle.Render("system control center")
	inner := lipgloss.JoinVertical(lipgloss.Center, brand, sub)
	box := styHeaderBox.Render(inner)

	meta := fmt.Sprintf("%s %s   %s %s",
		styMetaKey.Render("channel"), styMeta.Render(m.channel),
		styMetaKey.Render("version"), styMeta.Render(m.version))

	return lipgloss.JoinVertical(lipgloss.Left, box, "  "+meta, "  "+m.renderSweep(), "")
}

func (m model) renderMenu() string {
	var b strings.Builder
	for i, it := range m.items {
		cursor := "  "
		title := styItemTitle.Render(it.title)
		desc := styItemDesc.Render(it.desc)
		if i == m.cursor {
			cursor = styCursor.Render("▸ ")
			title = styItemTitleSel.Render(it.title)
			desc = styItemDescSel.Render(it.desc)
		}
		fmt.Fprintf(&b, " %s%-16s %s\n", cursor, title, desc)
	}
	b.WriteString("\n")
	if m.note != "" {
		b.WriteString("  " + m.note + "\n\n")
	}
	b.WriteString("  " + styHint.Render("↑/↓ move   enter select   q quit"))
	return b.String()
}

func (m model) renderSudoPrompt() string {
	brand := styBrand.Render("力  Sudo password required")
	sub := stySubtitle.Render("for: " + m.sudoFor.title)
	mask := strings.Repeat("•", len([]rune(m.sudoPasswd)))
	field := styMetaKey.Render("password ") + mask + styCursor.Render("▏")
	inner := lipgloss.JoinVertical(lipgloss.Center, brand, sub, "", field)
	if m.sudoError != "" {
		inner = lipgloss.JoinVertical(lipgloss.Center, inner, "", styErr.Render("✗ "+m.sudoError))
	}
	box := styHeaderBox.Render(inner)
	hint := styHint.Render("enter authenticate   esc cancel   ctrl+u clear")
	return "\n" + box + "\n  " + hint
}

func (m model) renderFinished() string {
	if m.finished == finishedLogs {
		title := stateGlyph(runOK) + " " + styPaneTitle.Render("Update log")
		body := "  " + title + "\n"
		if m.vpReady {
			body += styPaneBorder.Render(m.vp.View()) + "\n"
		}
		body += "  " + styHint.Render("enter back to menu   q quit   ↑/↓ scroll")
		return body
	}

	// post-run status (the live output already scrolled on the real terminal)
	var status string
	if m.exitCode == 0 {
		status = stateGlyph(runOK) + " " + styOK.Render(m.active.title+" complete")
	} else {
		status = stateGlyph(runFail) + " " + styErr.Render(fmt.Sprintf("%s failed (exit %d)", m.active.title, m.exitCode))
	}
	tip := styHint.Render("the full output scrolled above; pick Logs to review it")
	hint := styHint.Render("enter back to menu   q quit")
	return "\n  " + status + "\n  " + tip + "\n\n  " + hint
}

func (m model) sweepWidth() int {
	w := m.width/3 - 4
	if w < 10 {
		w = 10
	}
	if w > 40 {
		w = 40
	}
	return w
}

// renderSweep draws the harmonica-driven activity bar shown in the header.
func (m model) renderSweep() string {
	w := m.sweepWidth()
	pos := int(math.Round(m.sweepPos))
	if pos < 0 {
		pos = 0
	}
	if pos >= w {
		pos = w - 1
	}
	var b strings.Builder
	for i := 0; i < w; i++ {
		switch {
		case i == pos:
			b.WriteString(styBrand.Render("█"))
		case i == pos-1 || i == pos+1:
			b.WriteString(lipgloss.NewStyle().Foreground(colAccent2).Render("▓"))
		default:
			b.WriteString(styHint.Render("─"))
		}
	}
	return b.String()
}

// ----- viewport (Logs only) -----

func (m *model) layoutViewport() {
	if m.width == 0 || m.height == 0 {
		return
	}
	headerH := lipgloss.Height(m.renderHeader())
	vpH := m.height - headerH - 4
	if vpH < 3 {
		vpH = 3
	}
	vpW := m.width - 2
	if vpW < 10 {
		vpW = 10
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

	p := tea.NewProgram(newModel())
	if _, err := p.Run(); err != nil {
		fmt.Fprintln(os.Stderr, "ryoku-tui:", err)
		os.Exit(1)
	}
}
