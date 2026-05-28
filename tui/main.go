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
type sudoReadyMsg struct {
	item menuItem
	err  error
}
type animTickMsg time.Time

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
		spring:   harmonica.NewSpring(harmonica.FPS(animFPS), 5.0, 0.18),
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

	case sudoReadyMsg:
		if msg.err != nil {
			m.runState = runFail
			m.state = stateFinished
			m.animating = false
			m.appendLine(styErr.Render("✗ authentication failed: " + msg.err.Error()))
			return m, nil
		}
		return m, m.launchCaptured(msg.item)

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
		m.lines = readLog()
		m.runState = runOK
		m.state = stateFinished
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
		c := exec.Command("sudo", "-v")
		return m, tea.ExecProcess(c, func(err error) tea.Msg {
			return sudoReadyMsg{item: it, err: err}
		})
	}
	return m, tea.Batch(m.launchCaptured(it), animTick())
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
	default:
		body = lipgloss.JoinVertical(lipgloss.Left, header, m.renderResults())
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
	m.lines = append(m.lines, s)
	const maxLines = 4000
	if len(m.lines) > maxLines {
		m.lines = m.lines[len(m.lines)-maxLines:]
	}
	m.refreshViewport()
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
