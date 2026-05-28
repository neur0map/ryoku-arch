package main

import (
	"strings"

	"charm.land/lipgloss/v2"
)

// Fixed Ryoku palette. Per good-TUI practice (soft-serve / k9s), purple is the
// ONE primary accent (selection, brand, focus); everything else is achromatic
// so the interface reads calm and the accent actually means "look here". The
// ok/warn/err hues are reserved for semantic log/status lines only.
var (
	colAccent = lipgloss.Color("#b4a0ff") // the single brand accent (purple)
	colBorder = lipgloss.Color("#45475a") // muted card border (achromatic)
	colSelFg  = lipgloss.Color("#1b1b2b") // text on the accent selection bar

	colOK   = lipgloss.Color("#a6e3a1")
	colWarn = lipgloss.Color("#e5c890")
	colErr  = lipgloss.Color("#f38ba8")

	colFg     = lipgloss.Color("#cdd6f4") // titles / primary text
	colMuted  = lipgloss.Color("#7f849c") // descriptions / hints
	colMuted2 = lipgloss.Color("#9399b2") // subtitle / meta values
)

// cardLineW is the inner content width of the control-center card. Every line
// rendered inside the card is padded/truncated to exactly this width so the
// border is a clean fixed-width rectangle.
const cardLineW = 58

var (
	// The single contained card that holds the whole UI.
	styCard = lipgloss.NewStyle().
		Border(lipgloss.RoundedBorder()).
		BorderForeground(colBorder).
		Padding(1, 3)

	styBrand = lipgloss.NewStyle().Foreground(colAccent).Bold(true)

	stySubtitle = lipgloss.NewStyle().Foreground(colMuted)

	styMeta    = lipgloss.NewStyle().Foreground(colMuted2)
	styMetaKey = lipgloss.NewStyle().Foreground(colMuted)

	styItemTitle    = lipgloss.NewStyle().Foreground(colFg).Bold(true)
	styItemTitleSel = lipgloss.NewStyle().Foreground(colSelFg).Bold(true)
	styItemDesc     = lipgloss.NewStyle().Foreground(colMuted)
	styItemDescSel  = lipgloss.NewStyle().Foreground(colSelFg)

	// Full-width selection bar (the focused menu row).
	styRowSel = lipgloss.NewStyle().Background(colAccent)

	styDivider = lipgloss.NewStyle().Foreground(colBorder)
	styHint    = lipgloss.NewStyle().Foreground(colMuted)

	// Used by the standalone gum-replacement widgets (confirm/input/choose/...).
	styHeaderBox = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(colBorder).
			Padding(0, 3).
			Align(lipgloss.Center)
	styCursor = lipgloss.NewStyle().Foreground(colAccent).Bold(true)

	// Log-line / status accents.
	styPaneTitle  = lipgloss.NewStyle().Foreground(colAccent).Bold(true)
	styPaneBorder = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(colBorder)

	styOK  = lipgloss.NewStyle().Foreground(colOK).Bold(true)
	styErr = lipgloss.NewStyle().Foreground(colErr).Bold(true)
	styWarn = lipgloss.NewStyle().Foreground(colWarn).Bold(true)
)

// stateGlyph returns a colored status glyph for a run state.
func stateGlyph(s runState) string {
	switch s {
	case runOK:
		return styOK.Render("✓")
	case runFail:
		return styErr.Render("✗")
	case runActive:
		return styBrand.Render("●")
	default:
		return styHint.Render("○")
	}
}

// ---- layout helpers (always size to cardLineW so the card stays rectangular) ----

func centerLine(s string) string  { return lipgloss.PlaceHorizontal(cardLineW, lipgloss.Center, s) }
func leftLine(s string) string    { return lipgloss.PlaceHorizontal(cardLineW, lipgloss.Left, s) }
func divider() string             { return styDivider.Render(strings.Repeat("─", cardLineW)) }

// truncate clamps a plain (unstyled) string to w display cells with an ellipsis.
func truncate(s string, w int) string {
	r := []rune(s)
	if w <= 0 {
		return ""
	}
	if len(r) <= w {
		return s
	}
	if w == 1 {
		return "…"
	}
	return string(r[:w-1]) + "…"
}
