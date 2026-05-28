package main

// widgets.go — gum-free, drop-in replacements for the gum subcommands used
// across Ryoku's scripts. Each renders with lipgloss/bubbletea and mirrors
// gum's CLI contract (flags + stdout/exit code) so call sites only swap the
// binary name. Implemented so far: `confirm`, `style`.

import (
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
	"strings"

	"charm.land/bubbles/v2/spinner"
	tea "charm.land/bubbletea/v2"
	"charm.land/lipgloss/v2"
)

// ---------------------------------------------------------------------------
// confirm — branded yes/no, exit 0 (yes) / 1 (no).
//
//	ryoku-tui confirm [--default=yes|no] "Prompt text"
// ---------------------------------------------------------------------------

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

func isStdoutTTY() bool {
	fi, err := os.Stdout.Stat()
	if err != nil {
		return false
	}
	return (fi.Mode() & os.ModeCharDevice) != 0
}

// runDirect runs a command with the real stdio and returns its exit code.
func runDirect(args []string) int {
	c := exec.Command(args[0], args[1:]...)
	c.Stdin, c.Stdout, c.Stderr = os.Stdin, os.Stdout, os.Stderr
	if err := c.Run(); err != nil {
		if ee, ok := err.(*exec.ExitError); ok {
			return ee.ExitCode()
		}
		return 1
	}
	return 0
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

// ---------------------------------------------------------------------------
// style — render text with lipgloss, mirroring `gum style`. Non-interactive.
// Reads text from args, or from stdin when no text args are given.
//
//	ryoku-tui style [--foreground N] [--background N] [--border S]
//	                [--border-foreground N] [--bold] [--faint] [--italic]
//	                [--underline] [--strikethrough] [--padding "v h"]
//	                [--margin "v h"] [--align left|center|right]
//	                [--width N] [--height N] [--] text...
// ---------------------------------------------------------------------------

func runStyle(args []string) int {
	st := lipgloss.NewStyle()
	var texts []string

	for i := 0; i < len(args); i++ {
		a := args[i]
		key, inlineVal, hasInline := splitFlag(a)
		next := func() string {
			if hasInline {
				return inlineVal
			}
			if i+1 < len(args) {
				i++
				return args[i]
			}
			return ""
		}
		switch {
		case a == "--":
			texts = append(texts, args[i+1:]...)
			i = len(args)
		case key == "--bold":
			st = st.Bold(true)
		case key == "--faint":
			st = st.Faint(true)
		case key == "--italic":
			st = st.Italic(true)
		case key == "--underline":
			st = st.Underline(true)
		case key == "--strikethrough":
			st = st.Strikethrough(true)
		case key == "--foreground":
			st = st.Foreground(lipgloss.Color(next()))
		case key == "--background":
			st = st.Background(lipgloss.Color(next()))
		case key == "--border-foreground":
			st = st.BorderForeground(lipgloss.Color(next()))
		case key == "--border":
			st = st.Border(borderByName(next()))
		case key == "--align":
			st = st.Align(alignByName(next()))
		case key == "--width":
			st = st.Width(atoi(next()))
		case key == "--height":
			st = st.Height(atoi(next()))
		case key == "--padding":
			st = applyBox(st.Padding, next())
		case key == "--margin":
			st = applyBox(st.Margin, next())
		case strings.HasPrefix(a, "--"):
			// Unknown flag: swallow a following value if it isn't inline.
			if !hasInline {
				next()
			}
		default:
			texts = append(texts, a)
		}
	}

	text := strings.Join(texts, "\n")
	if len(texts) == 0 {
		if b, err := io.ReadAll(os.Stdin); err == nil {
			text = strings.TrimRight(string(b), "\n")
		}
	}
	fmt.Println(st.Render(text))
	return 0
}

func splitFlag(a string) (key, val string, hasInline bool) {
	if !strings.HasPrefix(a, "--") {
		return a, "", false
	}
	if eq := strings.IndexByte(a, '='); eq >= 0 {
		return a[:eq], a[eq+1:], true
	}
	return a, "", false
}

func atoi(s string) int {
	n, _ := strconv.Atoi(strings.TrimSpace(s))
	return n
}

func borderByName(name string) lipgloss.Border {
	switch strings.ToLower(strings.TrimSpace(name)) {
	case "rounded":
		return lipgloss.RoundedBorder()
	case "thick":
		return lipgloss.ThickBorder()
	case "double":
		return lipgloss.DoubleBorder()
	case "hidden":
		return lipgloss.HiddenBorder()
	case "none", "":
		return lipgloss.Border{}
	default:
		return lipgloss.NormalBorder()
	}
}

func alignByName(name string) lipgloss.Position {
	switch strings.ToLower(strings.TrimSpace(name)) {
	case "center":
		return lipgloss.Center
	case "right":
		return lipgloss.Right
	default:
		return lipgloss.Left
	}
}

// applyBox parses a gum/CSS-style "v h" / "t r b l" spacing string and calls the
// given lipgloss setter (Padding or Margin) with the parsed ints.
func applyBox(setter func(...int) lipgloss.Style, spec string) lipgloss.Style {
	fields := strings.Fields(spec)
	nums := make([]int, 0, len(fields))
	for _, f := range fields {
		nums = append(nums, atoi(f))
	}
	if len(nums) == 0 {
		return setter()
	}
	return setter(nums...)
}

// stdinLines reads newline-separated options from stdin (for choose/filter when
// options aren't passed as args).
func stdinLines() []string {
	b, err := io.ReadAll(os.Stdin)
	if err != nil || len(b) == 0 {
		return nil
	}
	var out []string
	for _, l := range strings.Split(strings.TrimRight(string(b), "\n"), "\n") {
		if l != "" {
			out = append(out, l)
		}
	}
	return out
}

// ---------------------------------------------------------------------------
// input — single-line text entry, mirroring `gum input`. Prints the entered
// text on accept (exit 0); exit 1 on cancel.
//
//	ryoku-tui input [--placeholder P] [--prompt PR] [--value V] [--header H] [--password]
// ---------------------------------------------------------------------------

func runInput(args []string) int {
	m := inputModel{prompt: "> "}
	for i := 0; i < len(args); i++ {
		key, inlineVal, hasInline := splitFlag(args[i])
		next := func() string {
			if hasInline {
				return inlineVal
			}
			if i+1 < len(args) {
				i++
				return args[i]
			}
			return ""
		}
		switch key {
		case "--placeholder":
			m.placeholder = next()
		case "--prompt":
			m.prompt = next()
		case "--value":
			m.value = next()
		case "--header":
			m.header = next()
		case "--password":
			m.password = true
		default:
			if !hasInline && strings.HasPrefix(args[i], "--") {
				next()
			}
		}
	}

	if !isTTY() {
		return 1
	}
	res, err := tea.NewProgram(m).Run()
	if err != nil {
		return 1
	}
	im, ok := res.(inputModel)
	if !ok || !im.accepted {
		return 1
	}
	fmt.Println(im.value)
	return 0
}

type inputModel struct {
	prompt      string
	placeholder string
	header      string
	value       string
	password    bool
	accepted    bool
	done        bool
}

func (m inputModel) Init() tea.Cmd { return nil }

func (m inputModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := msg.(tea.KeyPressMsg); ok {
		switch key.String() {
		case "enter":
			m.accepted, m.done = true, true
			return m, tea.Quit
		case "esc", "ctrl+c":
			m.done = true
			return m, tea.Quit
		case "backspace":
			r := []rune(m.value)
			if len(r) > 0 {
				m.value = string(r[:len(r)-1])
			}
		case "ctrl+u":
			m.value = ""
		default:
			if t := key.Text; t != "" {
				m.value += t
			}
		}
	}
	return m, nil
}

func (m inputModel) View() tea.View {
	if m.done {
		return tea.NewView("")
	}
	shown := m.value
	if m.password {
		shown = strings.Repeat("•", len([]rune(m.value)))
	}
	field := shown + styCursor.Render("▏")
	if m.value == "" && m.placeholder != "" {
		field = styHint.Render(m.placeholder) + styCursor.Render("▏")
	}
	var b strings.Builder
	if m.header != "" {
		b.WriteString(styPaneTitle.Render(m.header) + "\n")
	}
	b.WriteString(styMetaKey.Render(m.prompt) + field + "\n")
	b.WriteString(styHint.Render("enter submit   esc cancel"))
	return tea.NewView("\n" + b.String() + "\n")
}

// ---------------------------------------------------------------------------
// choose — pick one (or many with --no-limit) from a list, mirroring
// `gum choose`. Options come from args or stdin. Prints selection(s); exit 1
// on cancel.
//
//	ryoku-tui choose [--header H] [--no-limit] [--height N]
//	                 [--selected X] [--selected-prefix P] option...
// ---------------------------------------------------------------------------

func runChoose(args []string) int {
	m := chooseModel{height: 10, selPrefix: "✓ "}
	var opts []string
	for i := 0; i < len(args); i++ {
		a := args[i]
		key, inlineVal, hasInline := splitFlag(a)
		next := func() string {
			if hasInline {
				return inlineVal
			}
			if i+1 < len(args) {
				i++
				return args[i]
			}
			return ""
		}
		switch {
		case key == "--header":
			m.header = next()
		case key == "--no-limit":
			m.multi = true
		case key == "--limit":
			if atoi(next()) > 1 {
				m.multi = true
			}
		case key == "--height":
			m.height = atoi(next())
		case key == "--selected":
			m.preselect = next()
		case key == "--selected-prefix":
			m.selPrefix = next()
		case strings.HasPrefix(a, "--"):
			if !hasInline {
				next()
			}
		default:
			opts = append(opts, a)
		}
	}
	if len(opts) == 0 {
		opts = stdinLines()
	}
	if len(opts) == 0 {
		return 1
	}
	m.items = opts
	m.chosen = make(map[int]bool)
	for i, o := range opts {
		if o == m.preselect {
			m.cursor = i
		}
	}
	if m.height < 1 {
		m.height = len(opts)
	}

	if !isTTY() {
		return 1
	}
	res, err := tea.NewProgram(m).Run()
	if err != nil {
		return 1
	}
	cm, ok := res.(chooseModel)
	if !ok || !cm.accepted {
		return 1
	}
	for _, s := range cm.result() {
		fmt.Println(s)
	}
	return 0
}

type chooseModel struct {
	items     []string
	header    string
	multi     bool
	height    int
	preselect string
	selPrefix string
	cursor    int
	chosen    map[int]bool
	accepted  bool
	done      bool
}

func (m chooseModel) Init() tea.Cmd { return nil }

func (m chooseModel) result() []string {
	if !m.multi {
		return []string{m.items[m.cursor]}
	}
	var out []string
	for i, it := range m.items {
		if m.chosen[i] {
			out = append(out, it)
		}
	}
	return out
}

func (m chooseModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := msg.(tea.KeyPressMsg); ok {
		switch key.String() {
		case "up", "k":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down", "j":
			if m.cursor < len(m.items)-1 {
				m.cursor++
			}
		case " ":
			if m.multi {
				m.chosen[m.cursor] = !m.chosen[m.cursor]
			}
		case "enter":
			if m.multi && len(m.result()) == 0 {
				m.chosen[m.cursor] = true
			}
			m.accepted, m.done = true, true
			return m, tea.Quit
		case "esc", "ctrl+c", "q":
			m.done = true
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m chooseModel) View() tea.View {
	if m.done {
		return tea.NewView("")
	}
	var b strings.Builder
	if m.header != "" {
		b.WriteString(styPaneTitle.Render(m.header) + "\n")
	}
	start := 0
	if m.cursor >= m.height {
		start = m.cursor - m.height + 1
	}
	end := start + m.height
	if end > len(m.items) {
		end = len(m.items)
	}
	for i := start; i < end; i++ {
		cur := "  "
		text := styItemDesc.Render(m.items[i])
		if i == m.cursor {
			cur = styCursor.Render("▸ ")
			text = styItemTitleSel.Render(m.items[i])
		}
		mark := ""
		if m.multi {
			if m.chosen[i] {
				mark = styOK.Render(m.selPrefix)
			} else {
				mark = strings.Repeat(" ", len([]rune(m.selPrefix)))
			}
		}
		fmt.Fprintf(&b, " %s%s%s\n", cur, mark, text)
	}
	if m.multi {
		b.WriteString(styHint.Render("↑/↓ move   space select   enter confirm   esc cancel"))
	} else {
		b.WriteString(styHint.Render("↑/↓ move   enter select   esc cancel"))
	}
	return tea.NewView("\n" + b.String() + "\n")
}

// ---------------------------------------------------------------------------
// filter — fuzzy-filter stdin lines and pick one, mirroring `gum filter`.
// Prints the selection; exit 1 on cancel.
//
//	... | ryoku-tui filter [--header H] [--height N] [--placeholder P]
// ---------------------------------------------------------------------------

func runFilter(args []string) int {
	m := filterModel{height: 12, placeholder: "Type to filter…"}
	for i := 0; i < len(args); i++ {
		key, inlineVal, hasInline := splitFlag(args[i])
		next := func() string {
			if hasInline {
				return inlineVal
			}
			if i+1 < len(args) {
				i++
				return args[i]
			}
			return ""
		}
		switch key {
		case "--header":
			m.header = next()
		case "--height":
			m.height = atoi(next())
		case "--placeholder":
			m.placeholder = next()
		default:
			if !hasInline && strings.HasPrefix(args[i], "--") {
				next()
			}
		}
	}
	m.items = stdinLines()
	if len(m.items) == 0 {
		return 1
	}
	m.refilter()
	if m.height < 1 {
		m.height = 12
	}
	if !isTTY() {
		return 1
	}
	res, err := tea.NewProgram(m).Run()
	if err != nil {
		return 1
	}
	fm, ok := res.(filterModel)
	if !ok || !fm.accepted || len(fm.filtered) == 0 {
		return 1
	}
	fmt.Println(fm.items[fm.filtered[fm.cursor]])
	return 0
}

type filterModel struct {
	items       []string
	filtered    []int // indices into items
	query       string
	header      string
	placeholder string
	height      int
	cursor      int
	accepted    bool
	done        bool
}

func (m filterModel) Init() tea.Cmd { return nil }

// subsequenceMatch reports whether every rune of needle appears in haystack in
// order (case-insensitive) — a lightweight fuzzy match.
func subsequenceMatch(haystack, needle string) bool {
	if needle == "" {
		return true
	}
	h := strings.ToLower(haystack)
	n := strings.ToLower(needle)
	j := 0
	for i := 0; i < len(h) && j < len(n); i++ {
		if h[i] == n[j] {
			j++
		}
	}
	return j == len(n)
}

func (m *filterModel) refilter() {
	m.filtered = m.filtered[:0]
	for i, it := range m.items {
		if subsequenceMatch(it, m.query) {
			m.filtered = append(m.filtered, i)
		}
	}
	if m.cursor >= len(m.filtered) {
		m.cursor = len(m.filtered) - 1
	}
	if m.cursor < 0 {
		m.cursor = 0
	}
}

func (m filterModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	if key, ok := msg.(tea.KeyPressMsg); ok {
		switch key.String() {
		case "enter":
			if len(m.filtered) > 0 {
				m.accepted = true
			}
			m.done = true
			return m, tea.Quit
		case "esc", "ctrl+c":
			m.done = true
			return m, tea.Quit
		case "up":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down":
			if m.cursor < len(m.filtered)-1 {
				m.cursor++
			}
		case "backspace":
			r := []rune(m.query)
			if len(r) > 0 {
				m.query = string(r[:len(r)-1])
				m.refilter()
			}
		default:
			if t := key.Text; t != "" {
				m.query += t
				m.refilter()
			}
		}
	}
	return m, nil
}

func (m filterModel) View() tea.View {
	if m.done {
		return tea.NewView("")
	}
	var b strings.Builder
	if m.header != "" {
		b.WriteString(styPaneTitle.Render(m.header) + "\n")
	}
	q := m.query
	if q == "" {
		q = styHint.Render(m.placeholder)
	}
	b.WriteString(styMetaKey.Render("/ ") + q + styCursor.Render("▏") + "\n")

	start := 0
	if m.cursor >= m.height {
		start = m.cursor - m.height + 1
	}
	end := start + m.height
	if end > len(m.filtered) {
		end = len(m.filtered)
	}
	for i := start; i < end; i++ {
		text := styItemDesc.Render(m.items[m.filtered[i]])
		cur := "  "
		if i == m.cursor {
			cur = styCursor.Render("▸ ")
			text = styItemTitleSel.Render(m.items[m.filtered[i]])
		}
		fmt.Fprintf(&b, " %s%s\n", cur, text)
	}
	b.WriteString(styHint.Render(fmt.Sprintf("%d/%d   ↑/↓ move   enter select   esc cancel", len(m.filtered), len(m.items))))
	return tea.NewView("\n" + b.String() + "\n")
}

// ---------------------------------------------------------------------------
// spin — show a spinner with a title while a command runs, mirroring
// `gum spin`. Exits with the command's status.
//
//	ryoku-tui spin [--title T] [--spinner S] [--show-output] -- command [args...]
// ---------------------------------------------------------------------------

func runSpin(args []string) int {
	title := "Working…"
	showOutput := false
	var cmdArgs []string
	for i := 0; i < len(args); i++ {
		a := args[i]
		if a == "--" {
			cmdArgs = args[i+1:]
			break
		}
		key, inlineVal, hasInline := splitFlag(a)
		next := func() string {
			if hasInline {
				return inlineVal
			}
			if i+1 < len(args) {
				i++
				return args[i]
			}
			return ""
		}
		switch key {
		case "--title":
			title = next()
		case "--show-output":
			showOutput = true
		case "--spinner", "--align":
			next() // accepted, styling ignored (we use our own spinner)
		default:
			if !hasInline && strings.HasPrefix(a, "--") {
				next()
			}
		}
	}
	if len(cmdArgs) == 0 {
		return 0
	}

	// The spinner only makes sense on a real terminal; otherwise run the
	// command transparently so exit codes and output pass straight through.
	if !isStdoutTTY() {
		return runDirect(cmdArgs)
	}

	m := spinModel{title: title, showOutput: showOutput, args: cmdArgs}
	m.sp = spinner.New()
	m.sp.Spinner = spinner.Dot
	m.sp.Style = styBrand
	res, err := tea.NewProgram(m).Run()
	if err != nil {
		// Fall back to a plain run if the TUI can't start.
		return runDirect(cmdArgs)
	}
	sm, _ := res.(spinModel)
	if sm.showOutput && sm.output != "" {
		fmt.Print(sm.output)
	}
	return sm.code
}

type spinDoneMsg struct {
	code   int
	output string
}

type spinModel struct {
	title      string
	showOutput bool
	args       []string
	sp         spinner.Model
	output     string
	code       int
	done       bool
}

func (m spinModel) Init() tea.Cmd {
	return tea.Batch(m.sp.Tick, m.run())
}

func (m spinModel) run() tea.Cmd {
	args := m.args
	return func() tea.Msg {
		c := exec.Command(args[0], args[1:]...)
		out, err := c.CombinedOutput()
		code := 0
		if err != nil {
			if ee, ok := err.(*exec.ExitError); ok {
				code = ee.ExitCode()
			} else {
				code = 1
			}
		}
		return spinDoneMsg{code: code, output: string(out)}
	}
}

func (m spinModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case spinDoneMsg:
		m.code = msg.code
		m.output = msg.output
		m.done = true
		return m, tea.Quit
	case spinner.TickMsg:
		var cmd tea.Cmd
		m.sp, cmd = m.sp.Update(msg)
		return m, cmd
	case tea.KeyPressMsg:
		if msg.String() == "ctrl+c" {
			m.code = 130
			m.done = true
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m spinModel) View() tea.View {
	if m.done {
		return tea.NewView("")
	}
	return tea.NewView(" " + m.sp.View() + " " + styPaneTitle.Render(m.title) + "\n")
}
