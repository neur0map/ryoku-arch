package main

// visual language borrowed from installation/tui: same palette, glyph
// fallbacks, and brand gradient, so the shell installer reads as the same
// product as the ISO installer.

import (
	"fmt"
	"image/color"
	"os"
	"strings"

	"charm.land/lipgloss/v2"
)

var (
	cBg    = lipgloss.Color("#16161e")
	cText  = lipgloss.Color("#c0caf5")
	cSub   = lipgloss.Color("#7079b3")
	cDim   = lipgloss.Color("#3b4261")
	cBrand = lipgloss.Color("#F25623")
	cBlue  = lipgloss.Color("#7aa2f7")
	cGreen = lipgloss.Color("#9ece6a")
	cYell  = lipgloss.Color("#e0af68")
	cRed   = lipgloss.Color("#f7768e")
)

func sty() lipgloss.Style                 { return lipgloss.NewStyle() }
func fg(c color.Color, s string) string   { return sty().Foreground(c).Render(s) }
func bold(c color.Color, s string) string { return sty().Foreground(c).Bold(true).Render(s) }
func dw(s string) int                     { return lipgloss.Width(s) }

func truncW(s string, w int) string {
	if w <= 0 {
		return ""
	}
	if dw(s) <= w {
		return s
	}
	r := []rune(s)
	for len(r) > 0 && dw(string(r))+1 > w {
		r = r[:len(r)-1]
	}
	return string(r) + "…"
}

func padTo(s string, w int) string {
	if d := dw(s); d < w {
		return s + strings.Repeat(" ", w-d)
	}
	return s
}

func padLines(s string, w int) string {
	ls := strings.Split(s, "\n")
	for i := range ls {
		ls[i] = padTo(ls[i], w)
	}
	return strings.Join(ls, "\n")
}

func clamp(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

// glyphs with ASCII fallback for dumb/no-UTF8 consoles; colors need no
// fallback (lipgloss v2 downsamples truecolor itself).
var ascii bool
var (
	gCheck  = "✓"
	gBad    = "✗"
	gPend   = "·"
	gSel    = "▌ "
	gOn     = "● on "
	gOff    = "○ off"
	gFull   = "█"
	gEmpty  = "░"
	gArrow  = "▸"
	gWarn   = "▲"
	gBullet = "•"
)

var spinFrames = []string{"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"}

var asciiBorder = lipgloss.Border{Top: "-", Bottom: "-", Left: "|", Right: "|", TopLeft: "+", TopRight: "+", BottomLeft: "+", BottomRight: "+"}

func ruleCh() string {
	if ascii {
		return "-"
	}
	return "─"
}

func border() lipgloss.Border {
	if ascii {
		return asciiBorder
	}
	return lipgloss.RoundedBorder()
}

func borderDouble() lipgloss.Border {
	if ascii {
		return asciiBorder
	}
	return lipgloss.DoubleBorder()
}

func initGlyphs() {
	t := os.Getenv("TERM")
	ascii = os.Getenv("RYOKU_ASCII") != "" || t == "dumb" || t == "vt100" || t == ""
	if !ascii {
		return
	}
	gCheck, gBad, gPend, gSel = "+", "x", ".", "> "
	gOn, gOff = "[x]on ", "[ ]off"
	gFull, gEmpty, gArrow, gWarn, gBullet = "#", "-", ">", "^", "*"
	spinFrames = []string{"|", "/", "-", "\\"}
}

// brand gradient, vermilion to gold, same stops as the ISO installer.
var gradA = [3]int{0xF2, 0x56, 0x23}
var gradB = [3]int{0xFF, 0xD2, 0x4A}

func gradColor(t float64) color.Color {
	if t < 0 {
		t = 0
	}
	if t > 1 {
		t = 1
	}
	r := int(float64(gradA[0]) + float64(gradB[0]-gradA[0])*t)
	g := int(float64(gradA[1]) + float64(gradB[1]-gradA[1])*t)
	b := int(float64(gradA[2]) + float64(gradB[2]-gradA[2])*t)
	return lipgloss.Color(fmt.Sprintf("#%02x%02x%02x", r, g, b))
}

var bannerRows = []string{
	"█▀▄ █ █ █▀█ █▄▀ █ █",
	"█▀▄ ▀█▀ █ █ █▀▄ █ █",
	"▀ ▀ ░█░ ▀▀▀ ▀ ▀ ▀▀▀",
}

const bannerW = 19

// banner renders the RYOKU wordmark in the brand gradient; phase shifts the
// gradient for a slow shimmer.
func banner(phase int) string {
	if ascii {
		return bold(cBrand, "R Y O K U")
	}
	var out []string
	for _, row := range bannerRows {
		var b strings.Builder
		col := 0
		for _, r := range row {
			t := float64((col+phase)%bannerW) / float64(bannerW-1)
			b.WriteString(fg(gradColor(t), string(r)))
			col++
		}
		out = append(out, b.String())
	}
	return strings.Join(out, "\n")
}

func keyHint(k, desc string) string {
	return bold(cBrand, k) + " " + fg(cSub, desc)
}

func hintSep() string { return fg(cDim, "  ·  ") }
