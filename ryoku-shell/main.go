package main

// ryoku-shell-install: put the Ryoku desktop on an existing Arch machine, no
// ISO. Interactive bubbletea TUI by default; --yes runs the same engine
// headless. --dry-run prints every command instead of running it.

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"

	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

const minTermW, minTermH = 80, 24

type frameMsg time.Time
type scanMsg struct{ f *facts }

type planItem struct {
	label  string
	detail string
	on     *bool
}

type model struct {
	w, h  int
	frame int
	state string // scan, plan, install, done, failed

	f       *facts
	p       *plan
	items   []planItem
	sel     int
	confirm bool

	eng     *engine
	events  chan any
	stepIdx int
	logTail []string
	failIdx int
	failMsg string
	intAsk  bool // one ctrl+c pressed during install, awaiting the second

	dry        bool
	ref        string
	payload    string
	exitReboot bool
}

func newTUIModel(dry bool, ref, payload string) model {
	return model{state: "scan", dry: dry, ref: ref, payload: payload}
}

func (m model) tickCmd() tea.Cmd {
	d := 250 * time.Millisecond
	if m.state == "scan" || m.state == "install" {
		d = 90 * time.Millisecond
	}
	return tea.Tick(d, func(t time.Time) tea.Msg { return frameMsg(t) })
}

func scanCmd() tea.Msg { return scanMsg{f: detect()} }

func (m model) Init() tea.Cmd {
	return tea.Batch(m.tickCmd(), func() tea.Msg { return scanCmd() })
}

func (m model) waitEv() tea.Cmd {
	ch := m.events
	return func() tea.Msg { return <-ch }
}

func buildItems(f *facts, p *plan) []planItem {
	var it []planItem
	if f.hasNvidia {
		d := "installs the proprietary driver, blacklists nouveau, rebuilds the initramfs"
		if f.nouveauLive {
			d = "you are on nouveau right now; switching needs a reboot to take effect"
		}
		it = append(it, planItem{"NVIDIA proprietary drivers", d, &p.nvidia})
	}
	if dm := f.otherDM(); dm != "" {
		it = append(it, planItem{"Switch login to SDDM", "disables " + dm + " and enables the Ryoku greeter (at reboot)", &p.switchDM})
	} else if f.currentDM == "" {
		it = append(it, planItem{"Enable SDDM login", "no display manager found; toggle off to keep starting Hyprland by hand", &p.switchDM})
	}
	if len(f.otherNet) > 0 {
		it = append(it, planItem{"Switch to NetworkManager", "disables " + strings.Join(f.otherNet, ", ") + " (at reboot)", &p.switchNet})
	}
	if len(f.rivalPkgs) > 0 {
		it = append(it, planItem{"Remove rival shells", "uninstalls " + strings.Join(f.rivalPkgs, ", "), &p.rivals})
	}
	if len(f.softUnits) > 0 {
		it = append(it, planItem{"Disable conflicting daemons", "disables " + strings.Join(f.softUnits, ", "), &p.softOff})
	}
	it = append(it, planItem{"AUR extras", "wallust + awww (wallpaper engine), Bibata cursor, LocalSend, Handy", &p.aur})
	if !strings.HasSuffix(f.userShell, "/fish") {
		it = append(it, planItem{"fish as login shell", "Ryoku's default shell; your current one stays installed", &p.fish})
	}
	return it
}

func (m *model) startInstall() tea.Cmd {
	m.eng = newEngine(m.f, m.p, m.dry, m.ref, m.payload)
	m.events = m.eng.runFrom(0)
	m.stepIdx, m.logTail = 0, nil
	m.state = "install"
	return tea.Batch(m.tickCmd(), m.waitEv())
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.w, m.h = msg.Width, msg.Height
		return m, nil
	case frameMsg:
		m.frame++
		return m, m.tickCmd()
	case scanMsg:
		m.f = msg.f
		m.p = defaultPlan(m.f)
		m.items = buildItems(m.f, m.p)
		m.state = "plan"
		return m, nil
	case evStep:
		m.stepIdx = msg.idx
		return m, m.waitEv()
	case evLine:
		m.logTail = append(m.logTail, msg.line)
		if len(m.logTail) > 400 {
			m.logTail = m.logTail[len(m.logTail)-400:]
		}
		return m, m.waitEv()
	case evDone:
		if msg.err != nil {
			m.failIdx, m.failMsg = msg.idx, msg.err.Error()
			m.state = "failed"
		} else {
			m.state = "done"
		}
		return m, nil
	case tea.KeyPressMsg:
		return m.onKey(msg.String())
	}
	return m, nil
}

func (m model) onKey(k string) (tea.Model, tea.Cmd) {
	if k == "ctrl+c" {
		// quitting mid-install abandons a live root pacman transaction; make
		// that a deliberate double-press, not a slip.
		if m.state == "install" && !m.intAsk {
			m.intAsk = true
			return m, nil
		}
		return m, tea.Quit
	}
	if m.state == "install" && m.intAsk {
		m.intAsk = false
	}
	switch m.state {
	case "plan":
		if m.confirm {
			switch k {
			case "y", "Y", "enter":
				m.confirm = false
				return m, m.startInstall()
			case "n", "N", "esc":
				m.confirm = false
			}
			return m, nil
		}
		switch k {
		case "q":
			return m, tea.Quit
		case "j", "down":
			if m.sel < len(m.items)-1 {
				m.sel++
			}
		case "k", "up":
			if m.sel > 0 {
				m.sel--
			}
		case " ", "space":
			if len(m.items) > 0 {
				*m.items[m.sel].on = !*m.items[m.sel].on
			}
		case "enter":
			m.confirm = true
		}
	case "done":
		switch k {
		case "r":
			m.exitReboot = true
			return m, tea.Quit
		case "q", "enter":
			return m, tea.Quit
		}
	case "failed":
		switch k {
		case "r":
			m.events = m.eng.runFrom(m.failIdx)
			m.state = "install"
			return m, tea.Batch(m.tickCmd(), m.waitEv())
		case "q":
			return m, tea.Quit
		}
	}
	return m, nil
}

// ---- views ----

func (m model) View() tea.View {
	if m.w == 0 {
		return tea.NewView("")
	}
	if m.w < minTermW || m.h < minTermH {
		msg := lipgloss.JoinVertical(lipgloss.Center,
			bold(cYell, "↔  Please enlarge your terminal"), "",
			fg(cText, fmt.Sprintf("The Ryoku shell installer needs at least %d × %d.", minTermW, minTermH)),
			fg(cSub, fmt.Sprintf("Current size: %d × %d.", m.w, m.h)))
		v := tea.NewView(lipgloss.Place(m.w, m.h, lipgloss.Center, lipgloss.Center, msg))
		v.AltScreen, v.BackgroundColor, v.ForegroundColor = true, cBg, cText
		return v
	}
	var body string
	switch m.state {
	case "scan":
		body = m.viewScan()
	case "plan":
		body = m.viewPlan()
	case "install":
		body = m.viewInstall()
	case "done":
		body = m.viewDone()
	case "failed":
		body = m.viewFailed()
	}
	frame := lipgloss.Place(m.w, m.h, lipgloss.Center, lipgloss.Center, body)
	foot := m.footer()
	if foot != "" {
		lines := strings.Split(frame, "\n")
		if len(lines) >= 2 {
			lines[len(lines)-2] = lipgloss.PlaceHorizontal(m.w, lipgloss.Center, foot)
		}
		frame = strings.Join(lines, "\n")
	}
	v := tea.NewView(frame)
	v.AltScreen = true
	v.BackgroundColor = cBg
	v.ForegroundColor = cText
	v.WindowTitle = "Ryoku shell installer"
	return v
}

func (m model) footer() string {
	switch m.state {
	case "plan":
		if m.confirm {
			return keyHint("y", "install") + hintSep() + keyHint("n", "back")
		}
		return keyHint("↑↓", "move") + hintSep() + keyHint("space", "toggle") + hintSep() +
			keyHint("enter", "install") + hintSep() + keyHint("q", "quit")
	case "install":
		if m.intAsk {
			return bold(cRed, "a package transaction may be running; press ctrl+c again to abandon")
		}
		return fg(cDim, "installing, do not interrupt") + hintSep() + fg(cDim, "log: "+m.logPath())
	case "done":
		return keyHint("r", "reboot now") + hintSep() + keyHint("q", "quit")
	case "failed":
		return keyHint("r", "retry failed step") + hintSep() + keyHint("q", "quit")
	}
	return ""
}

func (m model) logPath() string {
	if m.eng != nil {
		return m.eng.logPath
	}
	return ""
}

func (m model) header(sub string) string {
	tag := fg(cSub, "shell installer")
	if m.dry {
		tag += fg(cYell, "  [dry run]")
	}
	return banner(m.frame/2) + "\n" + tag + "\n\n" + sub
}

func (m model) viewScan() string {
	sp := spinFrames[m.frame%len(spinFrames)]
	return m.header(fg(cBrand, sp) + " " + fg(cText, "inspecting this machine…"))
}

func (m model) viewPlan() string {
	f := m.f
	iw := clamp(m.w-14, 62, 96)

	var s strings.Builder
	row := func(k, v string) {
		s.WriteString(fg(cSub, padTo(k, 14)) + fg(cText, truncW(v, iw-16)) + "\n")
	}
	row("system", f.distroName)
	row("gpu", f.gpuSummary())
	dm := f.currentDM
	if dm == "" {
		dm = "none"
	}
	row("login", dm)
	if f.niriFound {
		row("compositor", "niri setup detected; its config is backed up, niri stays installed")
	}
	if len(f.rivalPkgs) > 0 {
		row("shells", strings.Join(f.rivalPkgs, ", "))
	}
	if f.ryokuOnBox {
		row("ryoku", "already installed; this run repairs and reconciles it")
	}
	if !f.online {
		s.WriteString(fg(cRed, gWarn+" repo.ryoku.dev unreachable, the install will fail without network") + "\n")
	}
	if f.btrfsRoot {
		row("snapshots", "btrfs root: snapper snapshots will be configured by ryoku doctor")
	} else {
		row("snapshots", "root is not btrfs: updates work, snapshot rollback is unavailable")
	}
	row("backup", "your touched configs are saved with a restore.sh before anything changes")
	info := sty().Border(border()).BorderForeground(cBlue).Padding(0, 2).Render(padLines(strings.TrimRight(s.String(), "\n"), iw))

	var t strings.Builder
	for i, it := range m.items {
		cur := "  "
		if i == m.sel {
			cur = fg(cBrand, gSel)
		}
		state := fg(cGreen, gOn)
		if !*it.on {
			state = fg(cDim, gOff)
		}
		lbl := fg(cText, padTo(it.label, 30))
		if i == m.sel {
			lbl = bold(cText, padTo(it.label, 30))
		}
		t.WriteString(cur + state + "  " + lbl + "\n")
		if i == m.sel {
			t.WriteString("     " + fg(cSub, truncW(it.detail, iw-6)) + "\n")
		}
	}
	toggles := sty().Border(border()).BorderForeground(cDim).Padding(0, 2).Render(padLines(strings.TrimRight(t.String(), "\n"), iw))

	body := m.header(bold(cText, "Here is the plan for "+f.hostname) + "\n\n" + info + "\n" + toggles)
	if m.confirm {
		q := bold(cBrand, "Install the Ryoku desktop with these choices?")
		body += "\n\n" + sty().Border(borderDouble()).BorderForeground(cBrand).Padding(0, 2).Render(q)
	}
	return body
}

func (m model) viewInstall() string {
	iw := clamp(m.w-12, 60, 100)
	bw := clamp(iw-10, 30, 70)
	logRows := clamp(m.h-20-len(m.eng.steps), 4, 12)

	total := len(m.eng.steps)
	prog := float64(m.stepIdx) / float64(total)
	fill := clamp(int(prog*float64(bw)), 0, bw)
	bar := fg(cBrand, strings.Repeat(gFull, fill)) + fg(cDim, strings.Repeat(gEmpty, bw-fill)) +
		fg(cSub, fmt.Sprintf(" %2d/%d", m.stepIdx, total))

	var b strings.Builder
	b.WriteString(bold(cBrand, "Installing the Ryoku desktop") + "\n\n")
	b.WriteString(bar + "\n\n")
	for i, s := range m.eng.steps {
		switch {
		case i < m.stepIdx:
			b.WriteString(fg(cGreen, gCheck+" ") + fg(cSub, s.title) + "\n")
		case i == m.stepIdx:
			b.WriteString(fg(cBrand, spinFrames[m.frame%len(spinFrames)]) + " " + fg(cText, s.title) + "\n")
		default:
			b.WriteString(fg(cDim, gPend+" "+s.title) + "\n")
		}
	}
	b.WriteString(fg(cDim, strings.Repeat(ruleCh(), iw)) + "\n")
	tail := m.logTail
	if len(tail) > logRows {
		tail = tail[len(tail)-logRows:]
	}
	for _, ln := range tail {
		b.WriteString(fg(cDim, truncW(ln, iw)) + "\n")
	}
	for i := len(tail); i < logRows; i++ {
		b.WriteString("\n")
	}
	return sty().Border(border()).BorderForeground(cBrand).Padding(1, 2).
		Render(padLines(strings.TrimRight(b.String(), "\n"), iw))
}

func (m model) viewDone() string {
	iw := clamp(m.w-14, 56, 90)
	var b strings.Builder
	b.WriteString(bold(cGreen, gCheck+" The Ryoku desktop is installed") + "\n\n")
	b.WriteString(fg(cText, "Reboot to land in the Ryoku greeter and your new session.") + "\n\n")
	b.WriteString(fg(cSub, gBullet+" updates forever:   ") + fg(cText, "ryoku update") + "\n")
	b.WriteString(fg(cSub, gBullet+" health checks:     ") + fg(cText, "ryoku doctor") + "\n")
	if m.eng != nil && m.eng.backupDir != "" {
		label := " your old configs:  "
		if m.eng.prevBackups > 0 {
			label = " this run's backup: "
		}
		b.WriteString(fg(cSub, gBullet+label) + fg(cText, m.eng.backupDir) + "\n")
		b.WriteString(fg(cSub, "                    (restore.sh inside undoes this run's changes)") + "\n")
		if m.eng.prevBackups > 0 {
			b.WriteString(fg(cYell, "                    earlier backups sit alongside; the oldest holds your pre-Ryoku configs") + "\n")
		}
	}
	b.WriteString(fg(cSub, gBullet+" install log:       ") + fg(cText, m.logPath()) + "\n\n")
	b.WriteString(fg(cSub, "First steps: ") + fg(cText, "Super+Space launcher · Super+, settings · Super+K keybinds") + "\n")
	return sty().Border(borderDouble()).BorderForeground(cGreen).Padding(1, 2).
		Render(padLines(strings.TrimRight(b.String(), "\n"), iw))
}

func (m model) viewFailed() string {
	iw := clamp(m.w-14, 56, 96)
	var b strings.Builder
	step := "?"
	if m.eng != nil && m.failIdx < len(m.eng.steps) {
		step = m.eng.steps[m.failIdx].title
	}
	b.WriteString(bold(cRed, gBad+" Install failed") + "\n\n")
	b.WriteString(fg(cText, "Step: ") + fg(cYell, step) + "\n")
	b.WriteString(fg(cText, "Error: ") + fg(cRed, truncW(m.failMsg, iw-8)) + "\n\n")
	tail := m.logTail
	if len(tail) > 8 {
		tail = tail[len(tail)-8:]
	}
	for _, ln := range tail {
		b.WriteString(fg(cDim, truncW(ln, iw)) + "\n")
	}
	b.WriteString("\n" + fg(cSub, "Full log: ") + fg(cText, m.logPath()) + "\n")
	b.WriteString(fg(cSub, "Completed steps keep their changes; retry resumes at the failed one.") + "\n")
	if m.eng != nil && m.eng.backupDir != "" {
		b.WriteString(fg(cSub, "To roll back instead: bash "+m.eng.backupDir+"/restore.sh") + "\n")
	}
	return sty().Border(border()).BorderForeground(cRed).Padding(1, 2).
		Render(padLines(strings.TrimRight(b.String(), "\n"), iw))
}

// ---- headless (--yes) ----

func runHeadless(dry bool, ref, payload string) int {
	fmt.Println(bold(cBrand, "ryoku-shell-install") + fg(cSub, " (headless)"))
	f := detect()
	p := defaultPlan(f)
	fmt.Printf("system: %s | gpu: %s | dm: %s\n", f.distroName, f.gpuSummary(), f.currentDM)
	fmt.Printf("plan: nvidia=%v sddm=%v networkmanager=%v remove-shells=%v aur=%v fish=%v\n",
		p.nvidia, p.switchDM, p.switchNet, p.rivals, p.aur, p.fish)
	e := newEngine(f, p, dry, ref, payload)
	ev := e.runFrom(0)
	for msg := range ev {
		switch msg := msg.(type) {
		case evStep:
			fmt.Println(bold(cBrand, fmt.Sprintf("==> [%d/%d] %s", msg.idx+1, len(e.steps), msg.title)))
		case evLine:
			fmt.Println("    " + msg.line)
		case evDone:
			if msg.err != nil {
				fmt.Println(bold(cRed, "install failed: "+msg.err.Error()))
				fmt.Println("log: " + e.logPath)
				return 1
			}
			fmt.Println(bold(cGreen, "the Ryoku desktop is installed; reboot to use it"))
			if e.backupDir != "" {
				fmt.Println("old configs: " + e.backupDir + " (restore.sh inside)")
			}
			return 0
		}
	}
	return 1
}

// ---- entry ----

func die(msg string) {
	fmt.Fprintln(os.Stderr, "ryoku-shell-install: "+msg)
	os.Exit(1)
}

func primeSudo() {
	if exec.Command("sudo", "-n", "true").Run() == nil {
		go sudoKeepalive()
		return
	}
	fmt.Println("ryoku-shell-install needs sudo for system changes; asking once up front.")
	c := exec.Command("sudo", "-v")
	if tty, err := os.OpenFile("/dev/tty", os.O_RDWR, 0); err == nil {
		c.Stdin, c.Stdout, c.Stderr = tty, tty, tty
	} else {
		c.Stdin, c.Stdout, c.Stderr = os.Stdin, os.Stdout, os.Stderr
	}
	if err := c.Run(); err != nil {
		die("sudo authentication failed")
	}
	go sudoKeepalive()
}

func sudoKeepalive() {
	for range time.Tick(60 * time.Second) {
		_ = exec.Command("sudo", "-n", "-v").Run()
	}
}

func stdoutIsTTY() bool {
	fi, err := os.Stdout.Stat()
	return err == nil && fi.Mode()&os.ModeCharDevice != 0
}

func main() {
	yes := flag.Bool("yes", false, "run non-interactively with the default plan")
	dry := flag.Bool("dry-run", false, "print every command instead of running it")
	ref := flag.String("ref", envOr("RYOKU_SHELL_REF", "main"), "ryoku-arch git ref for the payload")
	payload := flag.String("payload", os.Getenv("RYOKU_SHELL_PAYLOAD"), "use a local ryoku-arch checkout as the payload")
	flag.Parse()

	initGlyphs()

	if os.Geteuid() == 0 {
		die("run as your normal user, not root; sudo is used where needed")
	}
	if !has("pacman") {
		die("this installer needs an Arch-based system (pacman not found)")
	}
	if out("uname", "-m") != "x86_64" {
		die("the [ryoku] repository ships x86_64 packages only")
	}

	if !*dry {
		primeSudo()
	}

	if *yes {
		os.Exit(runHeadless(*dry, *ref, *payload))
	}
	if !stdoutIsTTY() {
		die("unable to run interactively; re-run with --yes for the default plan")
	}

	fm, err := tea.NewProgram(newTUIModel(*dry, *ref, *payload)).Run()
	if err != nil {
		die(err.Error())
	}
	if m, ok := fm.(model); ok && m.exitReboot {
		_ = exec.Command("systemctl", "reboot").Run()
	}
}

func envOr(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}
