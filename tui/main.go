// ryoku-tui — the unified Ryoku control center.
//
// A single bubbletea/lipgloss TUI: a fixed branded header on top, a menu of
// actions (Update, Doctor, Recovery, Logs, Manage packages), and a live
// results viewport underneath that streams the chosen action's output. It
// replaces the old gum-based update dashboard and doctor UI; the heavy lifting
// still lives in the bash engines (ryoku-update, ryoku-doctor, ryoku-call911now),
// which this front-end runs with their own UIs disabled and captures.
//
// Built on bubbletea v2 + lipgloss v2, with harmonica spring physics driving
// the live activity animation.
package main

import (
	"bufio"
	"fmt"
	"io"
	"math"
	"os"
	"os/exec"
	"strings"
	"time"

	"charm.land/bubbles/v2/spinner"
	"charm.land/bubbles/v2/viewport"
	tea "charm.land/bubbletea/v2"
	"github.com/charmbracelet/harmonica"
	"charm.land/lipgloss/v2"
)

type viewState int

const (
	stateMenu viewState = iota
	stateRunning
	stateFinished
	stateSudoPrompt
)

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

// ----- bubbletea messages -----

type lineMsg string
type doneMsg struct{ code int }
type animTickMsg time.Time
type sudoAuthResultMsg struct {
	item menuItem
	ok   bool
	err  string
}

type model struct {
	width, height int

	state  viewState
	cursor int
	items  []menuItem

	channel string
	version string

	vp      viewport.Model
	spin    spinner.Model
	vpReady bool

	active   menuItem
	runState runState
	started  time.Time
	exitCode int
	lines    []string
	out      chan tea.Msg

	note string

	// In-TUI sudo prompt state. We keep the typed password in memory only for
	// as long as the prompt is on screen; on submit/cancel it is cleared and
	// then handed once to `sudo -S -v` via stdin.
	sudoFor    menuItem
	sudoPasswd string
	sudoError  string

	// harmonica spring animation: a bright marker sweeps a bar while an action
	// runs (indeterminate activity). The spring is under-damped so it eases in
	// and gently overshoots at each end.
	spring     harmonica.Spring
	sweepPos   float64
	sweepVel   float64
	sweepTo    float64
	animating  bool
}

func newModel() model {
	sp := spinner.New()
	sp.Spinner = spinner.Dot
	sp.Style = styBrand

	items := []menuItem{
		{key: "update", title: "Update", desc: "fetch and apply the latest Ryoku + system packages", needsSudo: true},
		{key: "doctor", title: "Doctor", desc: "check system health and repair common problems", needsSudo: true},
		{key: "recovery", title: "Recovery", desc: "emergency MedEvac: rebuild a coherent install", needsSudo: true},
		{key: "logs", title: "Logs", desc: "view the most recent update log"},
		{key: "packages", title: "Manage packages", desc: "open the graphical package manager (gpk)", detached: true},
	}

	return model{
		state:    stateMenu,
		items:    items,
		channel:  detectChannel(),
		version:  detectVersion(),
		spin:     sp,
		runState: runIdle,
		// Smoother than the original 5.0/0.18 (which was visibly bouncy):
		// lower angular frequency + heavier damping for a gentle, controlled
		// ease at each end of the sweep.
		spring:   harmonica.NewSpring(harmonica.FPS(animFPS), 4.0, 0.75),
	}
}

func (m model) Init() tea.Cmd {
	return m.spin.Tick
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
		m.layoutViewport()
		return m, nil

	case tea.KeyPressMsg:
		return m.handleKey(msg)

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spin, cmd = m.spin.Update(msg)
		return m, cmd

	case animTickMsg:
		if !m.animating {
			return m, nil
		}
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
			// Stay on the password screen, surface the error, allow retry.
			m.sudoError = msg.err
			return m, nil
		}
		// Auth succeeded - launch the captured action.
		it := msg.item
		m.sudoFor = menuItem{}
		m.sudoError = ""
		m.active = it
		m.lines = nil
		m.runState = runActive
		m.state = stateRunning
		m.started = time.Now()
		m.note = ""
		m.animating = true
		m.sweepPos = 0
		m.sweepVel = 0
		m.sweepTo = float64(m.sweepWidth())
		m.layoutViewport()
		return m, tea.Batch(m.launchCaptured(it), animTick())

	case lineMsg:
		m.appendLine(string(msg))
		return m, waitFor(m.out)

	case doneMsg:
		m.exitCode = msg.code
		if msg.code == 0 {
			m.runState = runOK
		} else {
			m.runState = runFail
		}
		m.state = stateFinished
		m.animating = false
		m.refreshViewport()
		return m, nil
	}

	if m.state != stateMenu && m.vpReady {
		var cmd tea.Cmd
		m.vp, cmd = m.vp.Update(msg)
		return m, cmd
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
			// Cancel: wipe the secret and bounce back to the menu.
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
			m.sudoPasswd = "" // clear from model immediately on submit
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

	case stateRunning:
		if msg.String() == "ctrl+c" {
			return m, tea.Quit
		}
		var cmd tea.Cmd
		m.vp, cmd = m.vp.Update(msg)
		return m, cmd

	case stateFinished:
		switch msg.String() {
		case "q", "ctrl+c":
			return m, tea.Quit
		case "enter", "esc", "backspace":
			m.state = stateMenu
			m.runState = runIdle
			m.lines = nil
			m.note = ""
			return m, nil
		}
		var cmd tea.Cmd
		m.vp, cmd = m.vp.Update(msg)
		return m, cmd
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
		// Style every log line through the same prefix highlighter, so the
		// loaded log matches the live-streamed output's colour scheme.
		raw := readLog()
		m.lines = make([]string, len(raw))
		for i, line := range raw {
			m.lines[i] = applyLineStyle(line)
		}
		m.runState = runOK
		m.state = stateFinished
		// Set started so renderResults's `time.Since(m.started)` does not
		// produce a 2.5-billion-hour value when an instant action finishes.
		m.started = time.Now()
		m.layoutViewport()
		m.refreshViewport()
		return m, nil
	}

	m.active = it
	m.lines = nil
	m.runState = runActive
	m.state = stateRunning
	m.started = time.Now()
	m.note = ""
	m.animating = true
	m.sweepPos = 0
	m.sweepVel = 0
	m.sweepTo = float64(m.sweepWidth())
	m.layoutViewport()
	m.refreshViewport()

	if it.needsSudo && !sudoCached() {
		// Drop into the in-TUI password screen instead of suspending the
		// program. The password never leaves the bubbletea event loop until
		// it is handed once to `sudo -S -v`.
		m.sudoFor = it
		m.sudoPasswd = ""
		m.sudoError = ""
		m.state = stateSudoPrompt
		m.animating = false
		return m, nil
	}
	return m, tea.Batch(m.launchCaptured(it), animTick())
}

// trySudoAuth runs `sudo -S -v` with the supplied password piped on stdin.
// Returns a sudoAuthResultMsg whose ok mirrors sudo's exit status. The
// password is held only inside this closure for the lifetime of the call.
func trySudoAuth(it menuItem, password string) tea.Cmd {
	return func() tea.Msg {
		c := exec.Command("sudo", "-S", "-p", "", "-v")
		c.Stdin = strings.NewReader(password + "\n")
		var stderr strings.Builder
		c.Stderr = &stderr
		err := c.Run()
		if err == nil {
			return sudoAuthResultMsg{item: it, ok: true}
		}
		msg := "authentication failed"
		errOut := stderr.String()
		switch {
		case strings.Contains(errOut, "Sorry, try again") ||
			strings.Contains(errOut, "incorrect password"):
			msg = "incorrect password"
		case strings.Contains(errOut, "not allowed"):
			msg = "this user is not allowed to run sudo"
		case strings.Contains(errOut, "no tty"):
			msg = "sudo requires a tty (sudoers misconfiguration)"
		}
		return sudoAuthResultMsg{item: it, ok: false, err: msg}
	}
}

func (m *model) launchCaptured(it menuItem) tea.Cmd {
	name, args, env := commandFor(it)
	ch, err := runCmd(name, args, env)
	if err != nil {
		return func() tea.Msg { return doneMsg{code: 1} }
	}
	m.out = ch
	return tea.Batch(waitFor(ch), m.spin.Tick, animTick())
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
	default:
		body = lipgloss.JoinVertical(lipgloss.Left, header, m.renderResults())
	}
	// Centre the whole frame horizontally on the terminal. Vertical anchor
	// stays at the top so the live-results pane grows naturally downward.
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

	return lipgloss.JoinVertical(lipgloss.Left, box, "  "+meta, "")
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

func (m model) renderResults() string {
	elapsed := time.Since(m.started).Truncate(time.Second)
	var status string
	switch m.runState {
	case runActive:
		status = m.spin.View() + " " + styPaneTitle.Render(m.active.title) +
			styHint.Render(fmt.Sprintf("  %s elapsed  ", elapsed)) + m.renderSweep()
	case runOK:
		status = stateGlyph(runOK) + " " + styPaneTitle.Render(m.active.title+" complete") +
			styHint.Render(fmt.Sprintf("  %s", elapsed))
	case runFail:
		status = stateGlyph(runFail) + " " + styErr.Render(m.active.title+" failed") +
			styHint.Render(fmt.Sprintf("  exit %d", m.exitCode))
	}

	var hint string
	if m.state == stateFinished {
		hint = styHint.Render("enter back to menu   q quit   ↑/↓ scroll")
	} else {
		hint = styHint.Render("streaming…   ctrl+c quit   ↑/↓ scroll")
	}

	body := "  " + status + "\n"
	if m.vpReady {
		body += styPaneBorder.Render(m.vp.View()) + "\n"
	}
	body += "  " + hint
	return body
}

// renderSudoPrompt is the in-TUI password screen. The typed password is
// rendered as a row of • bullets so it never appears as plaintext on screen,
// and the password buffer lives only in the model (never in a viewport or
// the log).
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

// renderSweep draws the harmonica-driven indeterminate activity bar.
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

// ----- viewport helpers -----

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

func (m *model) appendLine(s string) {
	m.lines = append(m.lines, applyLineStyle(s))
	const maxLines = 4000
	if len(m.lines) > maxLines {
		m.lines = m.lines[len(m.lines)-maxLines:]
	}
	m.refreshViewport()
}

// applyLineStyle highlights common log prefixes in captured engine output so
// the viewport reads at a glance instead of being a wall of plain text. The
// bash engines run in plain mode for the TUI; this layer puts the colour back.
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
		// e.g. "[3/9] System packages" - stage banner from the legacy dashboard.
		return styPaneTitle.Render(s)
	}
	return s
}

func (m *model) refreshViewport() {
	if !m.vpReady {
		m.layoutViewport()
	}
	if !m.vpReady {
		return
	}
	m.vp.SetContent(strings.Join(m.lines, "\n"))
	m.vp.GotoBottom()
}

// ----- subprocess plumbing -----

func waitFor(ch chan tea.Msg) tea.Cmd {
	return func() tea.Msg {
		msg, ok := <-ch
		if !ok {
			return doneMsg{code: 0}
		}
		return msg
	}
}

func runCmd(name string, args []string, env []string) (chan tea.Msg, error) {
	cmd := exec.Command(name, args...)
	cmd.Env = append(os.Environ(), env...)

	if devnull, err := os.Open(os.DevNull); err == nil {
		cmd.Stdin = devnull
	}

	pr, pw := io.Pipe()
	cmd.Stdout = pw
	cmd.Stderr = pw

	if err := cmd.Start(); err != nil {
		return nil, err
	}

	ch := make(chan tea.Msg, 512)
	codeCh := make(chan int, 1)

	go func() {
		err := cmd.Wait()
		_ = pw.Close()
		code := 0
		if err != nil {
			if ee, ok := err.(*exec.ExitError); ok {
				code = ee.ExitCode()
			} else {
				code = 1
			}
		}
		codeCh <- code
	}()

	go func() {
		sc := bufio.NewScanner(pr)
		sc.Buffer(make([]byte, 0, 64*1024), 4*1024*1024)
		for sc.Scan() {
			ch <- lineMsg(stripCarriage(sc.Text()))
		}
		ch <- doneMsg{code: <-codeCh}
		close(ch)
	}()

	return ch, nil
}

func main() {
	// gum-free widget subcommands (drop-in for the gum subcommands of the same
	// name). With no subcommand, launch the full control center.
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
