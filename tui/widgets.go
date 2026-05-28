package main

// widgets.go — gum-free, drop-in replacements for the gum subcommands used
// across Ryoku's scripts. Each renders with lipgloss/bubbletea and mirrors
// gum's CLI contract (flags + stdout/exit code) so call sites only swap the
// binary name. Implemented so far: `confirm`, `style`.

import (
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"

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
