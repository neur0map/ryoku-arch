package main

import "charm.land/lipgloss/v2"

// Fixed Ryoku brand palette. Purple is the signature accent (the legacy bash
// dashboard used bright magenta / 35;1); the rest are chosen to read well on
// both dark and light terminals.
var (
	colAccent = lipgloss.Color("#b4a0ff") // ryoku purple
	colAccent2 = lipgloss.Color("#7c6cd1")
	colOK     = lipgloss.Color("#9ece6a")
	colWarn   = lipgloss.Color("#e0af68")
	colErr    = lipgloss.Color("#f7768e")
	colFg     = lipgloss.Color("#e9ecff")
	colMuted  = lipgloss.Color("#6c7086")
	colMuted2 = lipgloss.Color("#9399b2")
)

var (
	// Branded header box (fixed, pinned at the top).
	styHeaderBox = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(colAccent2).
			Padding(0, 3).
			Align(lipgloss.Center)

	styBrand = lipgloss.NewStyle().
			Foreground(colAccent).
			Bold(true)

	stySubtitle = lipgloss.NewStyle().
			Foreground(colMuted2)

	styMeta = lipgloss.NewStyle().
		Foreground(colMuted2)

	styMetaKey = lipgloss.NewStyle().
			Foreground(colAccent).
			Bold(true)

	// Menu rows.
	styItemTitle = lipgloss.NewStyle().
			Foreground(colFg).
			Bold(true)

	styItemTitleSel = lipgloss.NewStyle().
			Foreground(colAccent).
			Bold(true)

	styItemDesc = lipgloss.NewStyle().
			Foreground(colMuted)

	styItemDescSel = lipgloss.NewStyle().
			Foreground(colMuted2)

	styCursor = lipgloss.NewStyle().
			Foreground(colAccent).
			Bold(true)

	// Live-results pane.
	styPaneTitle = lipgloss.NewStyle().
			Foreground(colAccent).
			Bold(true)

	styPaneBorder = lipgloss.NewStyle().
			Border(lipgloss.NormalBorder(), true, false, false, false).
			BorderForeground(colAccent2)

	// Status / hint bar.
	styHint = lipgloss.NewStyle().
		Foreground(colMuted)

	styOK   = lipgloss.NewStyle().Foreground(colOK).Bold(true)
	styErr  = lipgloss.NewStyle().Foreground(colErr).Bold(true)
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
