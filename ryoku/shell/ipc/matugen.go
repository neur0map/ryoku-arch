package main

import (
	"encoding/json"
	"fmt"
	"image"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"math"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

// matugen.go is the dynamic colour pipeline and the sole renderer of the
// wallpaper palette. When Match wallpaper is on and no fixed named theme is
// selected, a wallpaper change (or a scheme-knob patch) runs matugen against the
// current image with the configured scheme arguments, writes the shell palette
// the Quickshell singletons read, and fans that same palette into the terminal,
// window border, system monitor, Qt, and (when app theming is on) the GTK / GUI
// app suite. Match wallpaper off, or a fixed named theme active, leaves the
// pipeline idle so it never fights the static palette the theme daemon owns.
//
// One knob store, one renderer: ~/.config/ryoku/matugen.json holds mode,
// contrast, prefer, the per-app roster and the app-suite toggle. The
// Hub appearance page writes that file; the daemon reads it and watches it, so a
// knob save retints exactly as a wallpaper change does. There is no second knob
// source and no second renderer.
//
// The installed matugen needs two passes:
//
//  1. Scheme generation:
//     matugen image <img> -t scheme-tonal-spot -m <mode> --contrast <c>
//     --lightness-dark <ld> --lightness-light <ll> --source-color-index <i>
//     --prefer <pref> --json hex --dry-run
//     emits the Material 3 palette on stdout and touches nothing on disk.
//  2. Templating:
//     the parsed palette is carried into `matugen -c <cfg> json <carrier>`, which
//     renders the deployed templates (kitty, the Hyprland border, btop, Qt, and,
//     when app theming is on, the GTK / GUI-app suite) from that one palette.
//
// The shell's own colors.json (the base16 keys the legacy reader consumes plus
// the camelCase Material 3 roles Theme.qml and Tokens.qml resolve) is authored
// here from the same palette, matching the shipped convention where the control
// plane owns colors.json and matugen fans it out.

// matugenKnobs are the scheme controls, read from the one knob store
// (~/.config/ryoku/matugen.json). The token values are matugen's own CLI
// vocabulary, so the constructed argv passes them straight through.
type matugenKnobs struct {
	Mode             string          // "dark" | "light" | "smart"
	Contrast         float64         // -1.0 .. 1.0
	LightnessDark    float64         // affine lightness transform for dark schemes
	LightnessLight   float64         // affine lightness transform for light schemes
	Prefer           string          // source-colour pick, e.g. "saturation"
	SourceColorIndex int             // 0..4, most dominant first
	ThemeRyokuApps   bool            // theme the GTK / GUI app suite (apps.toml)
	Templates        map[string]bool // per-app roster, keyed by group
}

// The value sets matugen accepts. An out-of-schema knob fails the run loudly
// rather than handing matugen a token it would reject.
var matugenPrefers = map[string]bool{
	"darkness": true, "lightness": true, "saturation": true,
	"less-saturation": true, "value": true, "closest-to-fallback": true,
}

// The one scheme Ryoku generates with. The picker that used to choose this was
// removed: half its options (monochrome, neutral) drain the colour out of every
// wallpaper, which reads as "live colours are broken" rather than as a choice,
// and the remaining spread is not worth a control that can silently do that.
const matugenSchemeType = "scheme-tonal-spot"

// defaultMatugenKnobs backs a missing or partial matugen.json so a run still
// produces a valid argv. They mirror the shipped matugen.json.
func defaultMatugenKnobs() matugenKnobs {
	return matugenKnobs{
		Mode:           "smart",
		Contrast:       0,
		Prefer:         "saturation",
		ThemeRyokuApps: true,
	}
}

// readMatugenKnobs reads the scheme controls from the one knob store
// (~/.config/ryoku/matugen.json), falling back to the shipped defaults for any
// that are absent so a partial file still produces a valid run.
func readMatugenKnobs() matugenKnobs {
	k := defaultMatugenKnobs()
	b, err := os.ReadFile(matugenKnobsPath())
	if err != nil {
		return k
	}
	var doc struct {
		Mode             *string         `json:"mode"`
		Contrast         *float64        `json:"contrast"`
		LightnessDark    *float64        `json:"lightnessDark"`
		LightnessLight   *float64        `json:"lightnessLight"`
		Prefer           *string         `json:"prefer"`
		SourceColorIndex *int            `json:"sourceColorIndex"`
		ThemeRyokuApps   *bool           `json:"themeRyokuApps"`
		Templates        map[string]bool `json:"templates"`
	}
	if json.Unmarshal(b, &doc) != nil {
		return k
	}
	if doc.Mode != nil && *doc.Mode != "" {
		k.Mode = *doc.Mode
	}
	if doc.Contrast != nil {
		k.Contrast = *doc.Contrast
	}
	if doc.LightnessDark != nil {
		k.LightnessDark = *doc.LightnessDark
	}
	if doc.LightnessLight != nil {
		k.LightnessLight = *doc.LightnessLight
	}
	if doc.Prefer != nil && *doc.Prefer != "" {
		k.Prefer = *doc.Prefer
	}
	if doc.SourceColorIndex != nil {
		k.SourceColorIndex = *doc.SourceColorIndex
	}
	if doc.ThemeRyokuApps != nil {
		k.ThemeRyokuApps = *doc.ThemeRyokuApps
	}
	k.Templates = doc.Templates
	return k
}

// matugenArgs builds the phase-1 (scheme generation) argv for the knobs and the
// already-resolved light/dark mode, or an error if a token is out of schema so a
// bad knob fails loudly. --prefer is required: the installed matugen refuses to
// pick a source colour non-interactively without it.
func matugenArgs(img string, k matugenKnobs, mode string) ([]string, error) {
	if mode != "dark" && mode != "light" {
		return nil, fmt.Errorf("unresolved mode %q (want dark|light)", mode)
	}
	if !matugenPrefers[k.Prefer] {
		return nil, fmt.Errorf("unknown prefer %q", k.Prefer)
	}
	c := k.Contrast
	if c < -1 {
		c = -1
	} else if c > 1 {
		c = 1
	}
	f := func(v float64) string { return strconv.FormatFloat(v, 'f', 2, 64) }
	return []string{
		"image", img,
		"-t", matugenSchemeType,
		"-m", mode,
		"--contrast", f(c),
		"--lightness-dark", f(k.LightnessDark),
		"--lightness-light", f(k.LightnessLight),
		"--source-color-index", strconv.Itoa(k.SourceColorIndex),
		"--prefer", k.Prefer,
		"--json", "hex",
		"--dry-run",
	}, nil
}

// smartMode maps a wallpaper's mean luma to a light/dark scheme: a dark image
// gets a dark scheme, a light image a light one, split at the mid-point. This is
// the "smart" mode's rule; the installed matugen's -m accepts only light|dark,
// so the choice is made here and passed through.
func smartMode(luma float64) string {
	if luma >= 0.5 {
		return "light"
	}
	return "dark"
}

// resolveMode turns the mode knob into a concrete light/dark for matugen: an
// explicit light/dark passes through; "smart" (or anything else) follows the
// wallpaper's luminance.
func resolveMode(mode, img string) string {
	switch mode {
	case "light", "dark":
		return mode
	}
	luma, ok := matugenImageLuma(img)
	if !ok {
		// Undecodable image: default to dark, the shell's own signature.
		return "dark"
	}
	return smartMode(luma)
}

// matugenImageLuma returns the wallpaper's mean perceptual luma in 0..1, using
// the shell's luma weights (dither.frag: 0.299/0.587/0.114). It decodes with the
// standard library (png/jpeg/gif) and falls back to a one-pixel ffmpeg downscale
// for formats the stdlib cannot read (webp), so every wallpaper the desktop
// accepts resolves a smart light/dark choice.
func matugenImageLuma(img string) (float64, bool) {
	if f, err := os.Open(img); err == nil {
		m, _, derr := image.Decode(f)
		f.Close()
		if derr == nil {
			return meanLuma(m), true
		}
	}
	return ffmpegLuma(img)
}

// meanLuma averages luma over a bounded grid so a 4K wallpaper stays cheap while
// still reflecting the whole frame.
func meanLuma(m image.Image) float64 {
	b := m.Bounds()
	if b.Empty() {
		return 0
	}
	const grid = 64
	sx := max(1, b.Dx()/grid)
	sy := max(1, b.Dy()/grid)
	var sum, n float64
	for y := b.Min.Y; y < b.Max.Y; y += sy {
		for x := b.Min.X; x < b.Max.X; x += sx {
			r, g, bl, _ := m.At(x, y).RGBA()
			sum += 0.299*float64(r>>8) + 0.587*float64(g>>8) + 0.114*float64(bl>>8)
			n++
		}
	}
	if n == 0 {
		return 0
	}
	return (sum / n) / 255
}

// ffmpegLuma downscales the image to a single area-averaged pixel and reads its
// luma, covering formats the stdlib image decoders miss. ffmpeg is already a
// daemon dependency (it samples video wallpapers).
func ffmpegLuma(img string) (float64, bool) {
	out, err := runCommandOutput("ffmpeg", "-v", "error", "-i", img,
		"-vf", "scale=1:1:flags=area", "-frames:v", "1", "-pix_fmt", "rgb24",
		"-f", "rawvideo", "-")
	if err != nil || len(out) < 3 {
		return 0, false
	}
	r, g, b := float64(out[0]), float64(out[1]), float64(out[2])
	return (0.299*r + 0.587*g + 0.114*b) / 255, true
}

// achromaticChroma is the mean-saturation floor a wallpaper must clear to count
// as carrying colour. Below it a picture is grayscale or monochrome, matugen has
// no source hue to extract and falls back to its built-in blue, so the palette
// is neutralized to match the wallpaper instead. Measured: a grayscale wall sits
// near 0, the least saturated real wallpapers near 0.12.
const achromaticChroma = 0.05

// imageAchromatic reports whether the wallpaper carries essentially no colour (a
// grayscale or monochrome picture). Decoded with the standard library,
// ffmpeg-downscaled for the formats it misses (webp); an undecodable image reads
// as chromatic, so a palette is never neutralized on a guess.
func imageAchromatic(img string) bool {
	if f, err := os.Open(img); err == nil {
		m, _, derr := image.Decode(f)
		f.Close()
		if derr == nil {
			return meanChroma(m) < achromaticChroma
		}
	}
	if c, ok := ffmpegChroma(img); ok {
		return c < achromaticChroma
	}
	return false
}

// meanChroma averages HSV saturation over the same bounded grid meanLuma walks,
// skipping near-black cells where hue is meaningless and sensor / JPEG noise
// dominates, so the measure reflects the picture's real colourfulness.
func meanChroma(m image.Image) float64 {
	b := m.Bounds()
	if b.Empty() {
		return 0
	}
	const grid = 64
	sx := max(1, b.Dx()/grid)
	sy := max(1, b.Dy()/grid)
	var sum, n float64
	for y := b.Min.Y; y < b.Max.Y; y += sy {
		for x := b.Min.X; x < b.Max.X; x += sx {
			r, g, bl, _ := m.At(x, y).RGBA()
			mx := max(r>>8, g>>8, bl>>8)
			if mx < 24 { // near-black: no meaningful hue
				continue
			}
			mn := min(r>>8, g>>8, bl>>8)
			sum += float64(mx-mn) / float64(mx)
			n++
		}
	}
	if n == 0 {
		return 0
	}
	return sum / n
}

// ffmpegChroma downscales to a small grid and averages saturation from the raw
// pixels, for the formats the stdlib decoders miss. A one-pixel average (what
// ffmpegLuma reads) washes all colour out, so chroma needs a grid.
func ffmpegChroma(img string) (float64, bool) {
	const n = 32
	out, err := runCommandOutput("ffmpeg", "-v", "error", "-i", img,
		"-vf", fmt.Sprintf("scale=%d:%d:flags=area", n, n),
		"-frames:v", "1", "-pix_fmt", "rgb24", "-f", "rawvideo", "-")
	if err != nil || len(out) < n*n*3 {
		return 0, false
	}
	var sum, cnt float64
	for i := 0; i+2 < len(out); i += 3 {
		mx := max(out[i], out[i+1], out[i+2])
		if mx < 24 {
			continue
		}
		mn := min(out[i], out[i+1], out[i+2])
		sum += float64(mx-mn) / float64(mx)
		cnt++
	}
	if cnt == 0 {
		return 0, true
	}
	return sum / cnt, true
}

// syncFollowWallpaper makes theme.json's followWallpaper track the selected
// scheme. Without it the two disagree: the Appearance page and the sidebar write
// theme.theme, nothing writes followWallpaper, and the live path is gated on
// followWallpaper alone -- so picking the live scheme after anything had turned
// it off (a rice, a fixed palette) selected a scheme that never regenerated.
// theme.theme is the master; this is its shadow. Other keys in the file
// (themeApps) are preserved.
func syncFollowWallpaper(themeName string) {
	path := filepath.Join(ryokuConfigDir(), "theme.json")
	doc := map[string]any{}
	if b, err := os.ReadFile(path); err == nil {
		_ = json.Unmarshal(b, &doc)
	}
	// Only the Wallpaper variant drives the live pipeline. Default is the
	// monochrome base (the shell's compiled palette -- the shipped default and
	// the Appearance MONO card), and every named theme owns a fixed palette;
	// none of them follow the wallpaper, so their shadow key is off. This matches
	// the fresh-install state (theme.theme "Default", no theme.json -> Match
	// wallpaper off) instead of fighting it the moment the picker is touched.
	follow := themeName == "Wallpaper"
	if cur, ok := doc["followWallpaper"].(bool); ok && cur == follow {
		return
	}
	doc["followWallpaper"] = follow
	_ = writeJSONFile(path, doc)
}

// matchWallpaperOn reports whether the colour master follows the wallpaper. The
// key lives in theme.json (the single source the daemon, window borders and shell
// chrome all read), defaulting ON to match the shell's own Config default: a
// fresh box with no theme.json (or a file missing the key) follows the wallpaper.
func matchWallpaperOn() bool {
	b, err := os.ReadFile(filepath.Join(ryokuConfigDir(), "theme.json"))
	if err != nil {
		return true
	}
	s := struct {
		FollowWallpaper *bool `json:"followWallpaper"`
	}{}
	if json.Unmarshal(b, &s) != nil || s.FollowWallpaper == nil {
		return true
	}
	return *s.FollowWallpaper
}

// staticThemeName returns the fixed named theme selected in shell.json, or ""
// for the two dynamic variants (Default, Wallpaper) and an absent key. A named
// theme's palette is the catalog's (themePalettes), which the daemon fans into
// both the shell rail and the app templates so the two share one master.
func staticThemeName() string {
	b, err := os.ReadFile(filepath.Join(ryokuConfigDir(), "shell.json"))
	if err != nil {
		return ""
	}
	s := struct {
		Theme struct {
			Theme string `json:"theme"`
		} `json:"theme"`
	}{}
	if json.Unmarshal(b, &s) != nil {
		return ""
	}
	if !staticName(s.Theme.Theme) {
		return ""
	}
	return s.Theme.Theme
}

// staticThemeActive reports whether a fixed named theme is selected. Its palette
// is owned by the theme catalog, and the dynamic wallpaper pipeline stays idle so
// it never fights that static palette; the static render path drives apps instead.
func staticThemeActive() bool { return staticThemeName() != "" }

// staticName reports whether a theme.theme value names a fixed palette, as
// opposed to the two dynamic variants. The one place the distinction is made.
func staticName(name string) bool {
	switch name {
	case "", "Default", "Wallpaper":
		return false
	}
	return true
}

// matugenFollows reports whether the dynamic matugen pipeline owns the palette
// now: Match wallpaper on and no fixed named theme selected.
func matugenFollows() bool {
	return matchWallpaperOn() && !staticThemeActive()
}

// matugenApply runs the whole pipeline for one image: generate the scheme with
// the configured knobs, author the shell palette, fan it into the app templates,
// and nudge the toolkits to repaint. A video wallpaper is sampled to a still
// first, since matugen decodes images only.
func (d *daemon) matugenApply(img string) error {
	if isVideo(img) {
		frame := liveFrame(img)
		if frame == "" {
			return fmt.Errorf("matugen: could not sample a still frame from %q", img)
		}
		img = frame
	}
	pal, tones, mode, err := generatePaletteStill(img)
	if err != nil {
		return err
	}

	// Author the shell's own palette: the one file every Quickshell singleton
	// reads (base16 for the legacy reader, camelCase Material 3 roles for
	// Theme.qml and Tokens.qml).
	if err := writeJSONFile(matugenColorsPath(), matugenColorsJSON(pal)); err != nil {
		return fmt.Errorf("matugen colors.json: %w", err)
	}

	// And the tonal ramps behind those roles, from the same run.
	if tones != nil {
		if err := writeJSONFile(matugenTonesPath(), tones); err != nil {
			fmt.Fprintf(os.Stderr, "matugen tones.json: %v\n", err)
		}
	}

	// Fan the same palette into the app suite through matugen's templating pass,
	// gated by the per-app roster and the app-suite toggle.
	matugenRenderTemplates(matugenShellPalette(pal), readMatugenKnobs())

	// Toolkit nudges so running apps re-read the regenerated configs. Hyprland is
	// reloaded by the caller (paintWorker).
	matugenReload(mode)
	return nil
}

// generatePaletteStill runs matugen on a still image with the configured knobs
// and neutralizes an achromatic picture, returning the shell palette, the tonal
// ramps, and the resolved light/dark mode -- the exact values matugenApply
// writes, with no cache writes and no desktop effects. Shared by apply and the
// ryowalls preview so the specimen never diverges from what Set paints.
func generatePaletteStill(img string) (map[string]string, map[string]map[string]string, string, error) {
	k := readMatugenKnobs()
	mode := resolveMode(k.Mode, img)
	args, err := matugenArgs(img, k, mode)
	if err != nil {
		return nil, nil, "", err
	}
	out, err := runMatugenCapture(args)
	if err != nil {
		return nil, nil, "", err
	}
	pal, err := parseMatugenPalette(out, mode)
	if err != nil {
		return nil, nil, "", err
	}
	tones := parseMatugenTones(out)

	// A wallpaper with essentially no colour gives matugen no source hue to
	// extract, so it falls back to its built-in blue and paints a blue palette
	// onto a black-and-white picture. Strip the invented hue to grays that match
	// the picture, luminance preserved so every contrast still lands.
	if imageAchromatic(img) {
		neutralizePalette(pal)
		neutralizeTones(tones)
	}
	return pal, tones, mode, nil
}

// matugenPreview prints, as JSON, the palette an image WOULD produce on apply --
// the shell colours, the tonal ramps, and the wallpaper's 8x8 L* map -- without
// touching the cache or the desktop. ryowalls calls it so its live preview and
// spectrum specimen show exactly what Set will paint (one generator, no drift).
func matugenPreview(img string) error {
	if isVideo(img) {
		if f := liveFrame(img); f != "" {
			img = f
		} else {
			return fmt.Errorf("matugen-preview: could not sample a still from %q", img)
		}
	}
	pal, tones, _, err := generatePaletteStill(img)
	if err != nil {
		return err
	}
	out := map[string]any{
		"colors": matugenColorsJSON(pal),
		"tones":  tones,
	}
	if grid, ok := wallToneGrid(img); ok {
		var sum float64
		for _, v := range grid {
			sum += v
		}
		out["grid"] = grid
		out["cols"] = wallToneCols
		out["rows"] = wallToneRows
		out["lstar"] = round2(sum / float64(len(grid)))
	}
	return json.NewEncoder(os.Stdout).Encode(out)
}

// matugenApplyStatic renders the app templates from a fixed named theme's curated
// palette and nudges the toolkits, so a static theme reaches the same terminal /
// monitor / GUI suite the wallpaper path does. Shell rail and apps then follow one
// master instead of splitting (rail static, apps stuck on the last wallpaper
// render). No wallpaper is involved; the palette is the catalog's.
func (d *daemon) matugenApplyStatic(name string) error {
	pal, ok := lookupThemePalette(name)
	if !ok {
		return fmt.Errorf("no palette for static theme %q", name)
	}
	shell := staticThemePalette(pal)
	// Author the shell palette too, so every colors.json reader (the launcher and
	// the desktop surfaces) tracks a fixed named theme, not only the wallpaper
	// path: the control plane owns colors.json for both palette sources.
	if err := writeJSONFile(matugenColorsPath(), matugenColorsJSON(shell)); err != nil {
		return fmt.Errorf("matugen colors.json (static): %w", err)
	}
	k := readMatugenKnobs()
	matugenRenderTemplates(matugenShellPalette(shell), k)
	matugenReload(staticPaletteMode(shell))
	// A catalog theme has no ramps, so the last wallpaper's are now wrong. The
	// file's absence is the gate: Ink re-lights the theme's own roles instead.
	_ = os.Remove(matugenTonesPath())
	return nil
}

// staticThemePalette converts a catalog theme's camelCase role palette into the
// snake_case flat palette the templating pass consumes, then fills the extended
// Material roles the catalog omits (surface_bright/dim, the *_fixed accent tones,
// inverse_primary) from the curated set, so every template block resolves instead
// of rendering an empty value. Each extended tone collapses onto the nearest
// curated role that stays legible on the theme's surface.
func staticThemePalette(pal map[string]string) map[string]string {
	conv := map[string]string{"background": "background", "onBackground": "on_background"}
	for _, kv := range matugenRoleKeys { // kv = {snake, camel}
		conv[kv[1]] = kv[0]
	}
	out := make(map[string]string, len(pal)+16)
	for camel, hex := range pal {
		if snake, ok := conv[camel]; ok && hex != "" {
			out[snake] = hex
		}
	}
	fill := func(k, from string) {
		if out[k] == "" {
			out[k] = out[from]
		}
	}
	// Extended surfaces approximate the container ramp.
	fill("surface_bright", "surface_container_high")
	fill("surface_dim", "surface_container_low")
	// The catalog carries only the main accent plus its container, so the fixed
	// accent tones collapse onto the legible main accent.
	fill("primary_fixed", "primary")
	fill("primary_fixed_dim", "primary")
	fill("secondary_fixed", "secondary")
	fill("secondary_fixed_dim", "secondary")
	fill("tertiary_fixed", "tertiary")
	fill("tertiary_fixed_dim", "tertiary")
	fill("inverse_primary", "primary")
	// On-fixed inks used as syntax / dim colours: keep them contrasting a surface.
	fill("on_primary_fixed", "on_primary_container")
	fill("on_primary_fixed_variant", "on_surface_variant")
	fill("on_secondary_fixed", "on_secondary_container")
	fill("on_secondary_fixed_variant", "on_surface_variant")
	fill("on_tertiary_fixed", "on_tertiary_container")
	fill("on_tertiary_fixed_variant", "on_surface_variant")
	return out
}

// staticPaletteMode picks light/dark for a static palette from its surface luma,
// so the toolkit reload sets the matching libadwaita colour-scheme preference.
func staticPaletteMode(shell map[string]string) string {
	if l, ok := hexLuma(shell["surface"]); ok && l >= 0.5 {
		return "light"
	}
	return "dark"
}

// hexLuma returns a #rrggbb colour's mean perceptual luma in 0..1 (the shell's
// 0.299/0.587/0.114 weights), or ok=false when the string is not a hex colour.
func hexLuma(hex string) (float64, bool) {
	h := strings.TrimPrefix(hex, "#")
	if len(h) != 6 {
		return 0, false
	}
	v, err := strconv.ParseInt(h, 16, 64)
	if err != nil {
		return 0, false
	}
	r := float64((v >> 16) & 0xff)
	g := float64((v >> 8) & 0xff)
	b := float64(v & 0xff)
	return (0.299*r + 0.587*g + 0.114*b) / 255.0, true
}

// runMatugenCapture runs matugen and returns its stdout, folding stderr into the
// error so a failed scheme generation is diagnosable in the daemon log.
func runMatugenCapture(args []string) ([]byte, error) {
	cmd := exec.Command("matugen", args...)
	var errBuf strings.Builder
	cmd.Stderr = &errBuf
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("matugen %s: %w: %s", args[0], err, strings.TrimSpace(errBuf.String()))
	}
	return out, nil
}

// parseMatugenPalette pulls the flat role -> hex palette out of matugen's --json
// output for the active mode, falling back through default/dark/light so a role
// missing the requested mode still resolves.
func parseMatugenPalette(out []byte, modeKey string) (map[string]string, error) {
	var doc struct {
		Colors map[string]map[string]struct {
			Color string `json:"color"`
			Hex   string `json:"hex"`
		} `json:"colors"`
	}
	if err := json.Unmarshal(out, &doc); err != nil {
		return nil, fmt.Errorf("matugen json: %w", err)
	}
	if len(doc.Colors) == 0 {
		return nil, fmt.Errorf("matugen output carried no colors")
	}
	order := []string{modeKey, "default", "dark", "light"}
	pal := make(map[string]string, len(doc.Colors))
	for role, buckets := range doc.Colors {
		for _, m := range order {
			e, ok := buckets[m]
			if !ok {
				continue
			}
			if e.Color != "" {
				pal[role] = e.Color
				break
			}
			if e.Hex != "" {
				pal[role] = e.Hex
				break
			}
		}
	}
	if len(pal) == 0 {
		return nil, fmt.Errorf("matugen output had no usable colors")
	}
	return pal, nil
}

// parseMatugenTones pulls the six tonal palettes out of the same --json output
// the roles come from, as ramp -> tone -> hex. matugen computes them on every
// run and the pipeline used to drop them. A role is one tone chosen to read on
// a surface; a surface-less spectrum bar has to pick its own, and taking it off
// the ramp keeps the chroma Material tuned for that tone.
func parseMatugenTones(out []byte) map[string]map[string]string {
	var doc struct {
		Palettes map[string]map[string]struct {
			Color string `json:"color"`
			Hex   string `json:"hex"`
		} `json:"palettes"`
	}
	if json.Unmarshal(out, &doc) != nil || len(doc.Palettes) == 0 {
		return nil
	}
	ramps := make(map[string]map[string]string, len(doc.Palettes))
	for name, tones := range doc.Palettes {
		ramp := make(map[string]string, len(tones))
		for tone, e := range tones {
			switch {
			case e.Color != "":
				ramp[tone] = e.Color
			case e.Hex != "":
				ramp[tone] = e.Hex
			}
		}
		if len(ramp) > 0 {
			ramps[matugenRampName(name)] = ramp
		}
	}
	if len(ramps) == 0 {
		return nil
	}
	return ramps
}

// matugenRampName renders a ramp name in the camelCase the QML side reads.
func matugenRampName(name string) string {
	if name == "neutral_variant" {
		return "neutralVariant"
	}
	return name
}

// neutralizeHex returns the gray with the same relative luminance as hex: the
// (invented) hue removed, the lightness -- and so every contrast the shell
// derives from the palette -- left exactly where it was. A non-#rrggbb value
// passes through untouched.
func neutralizeHex(hex string) string {
	h := strings.TrimPrefix(hex, "#")
	if len(h) != 6 {
		return hex
	}
	v, err := strconv.ParseInt(h, 16, 64)
	if err != nil {
		return hex
	}
	y := relLuminance(uint8(v>>16), uint8(v>>8), uint8(v))
	n := int(math.Round(srgbFromLinear(y) * 255))
	if n < 0 {
		n = 0
	} else if n > 255 {
		n = 255
	}
	return fmt.Sprintf("#%02x%02x%02x", n, n, n)
}

// srgbFromLinear gamma-encodes a linear channel, the inverse of the linearise in
// relLuminance, so a luminance maps back to an 8-bit sRGB gray.
func srgbFromLinear(u float64) float64 {
	if u <= 0.0031308 {
		return u * 12.92
	}
	return 1.055*math.Pow(u, 1.0/2.4) - 0.055
}

// neutralizePalette strips every role to its gray, in place.
func neutralizePalette(pal map[string]string) {
	for k, v := range pal {
		pal[k] = neutralizeHex(v)
	}
}

// neutralizeTones strips every tone of every ramp to its gray, in place; a nil
// map (no ramps were published) is left alone.
func neutralizeTones(tones map[string]map[string]string) {
	for _, ramp := range tones {
		for t, v := range ramp {
			ramp[t] = neutralizeHex(v)
		}
	}
}

// matugenBase16 maps the Material 3 palette onto the sixteen-colour base16 keys
// the legacy reader (and the terminal / Qt templates) consume. The role
// assignment matches the shipped engine so both palette sources read alike.
//
// The accent slots (color5/6/9/13) map to the main accent roles (primary,
// secondary, tertiary, error), never the *_container / inverse_primary roles.
// A container role is a low-emphasis fill whose lightness inverts between modes:
// it clears 3:1 on the dark surface but washes to ~2.6:1 on a light one -- the
// pale-on-pale btop meters and washed terminal accents on a cream palette. The
// main accents are the tones M3 designs to contrast the surface, so they stay
// legible in both modes. color8 (bright black) stays `outline`, a mid gray
// legible on either surface, for muted text and comments -- not surface_variant,
// a background role that painted muted ink invisibly dark-on-dark.
func matugenBase16(pal map[string]string) map[string]string {
	pick := func(k, fallback string) string {
		if v := pal[k]; v != "" {
			return v
		}
		return fallback
	}
	bg := pick("surface", pick("background", "#121212"))
	fg := pick("on_surface", pick("on_background", "#e6e6e6"))
	primary := pick("primary", "#a8c7fa")
	secondary := pick("secondary", "#7cacf8")
	tertiary := pick("tertiary", "#ffb4a9")
	errc := pick("error", "#ffb4ab")
	outline := pick("outline", "#8e918f")
	return map[string]string{
		"background": bg, "foreground": fg, "cursor": fg,
		"color0": bg, "color1": errc, "color2": primary, "color3": tertiary,
		"color4": secondary, "color5": primary,
		"color6": tertiary, "color7": fg,
		"color8": outline, "color9": errc,
		"color10": primary, "color11": tertiary, "color12": secondary,
		"color13": primary, "color14": outline,
		"color15": pick("on_primary_container", fg),
	}
}

// matugenShellPalette is the carrier palette handed to the templating pass: the
// base16 keys plus every raw Material 3 role, so a template resolves whether it
// names base16 slots (kitty, Qt) or Material 3 roles (GTK, discord).
func matugenShellPalette(pal map[string]string) map[string]string {
	m := matugenBase16(pal)
	for k, v := range pal {
		if v != "" {
			m[k] = v
		}
	}
	return m
}

// matugenRoleKeys maps matugen's snake_case Material 3 roles to the camelCase
// keys Theme.qml resolves, so the shell palette JSON keys line up with the 30
// roles (plus shadow and scrim) the pill reads.
var matugenRoleKeys = [][2]string{
	{"surface", "surface"},
	{"surface_variant", "surfaceVariant"},
	{"surface_container_lowest", "surfaceContainerLowest"},
	{"surface_container_low", "surfaceContainerLow"},
	{"surface_container", "surfaceContainer"},
	{"surface_container_high", "surfaceContainerHigh"},
	{"surface_container_highest", "surfaceContainerHighest"},
	{"inverse_surface", "inverseSurface"},
	{"inverse_on_surface", "inverseOnSurface"},
	{"surface_tint", "surfaceTint"},
	{"primary", "primary"},
	{"primary_container", "primaryContainer"},
	{"secondary", "secondary"},
	{"secondary_container", "secondaryContainer"},
	{"tertiary", "tertiary"},
	{"tertiary_container", "tertiaryContainer"},
	{"error", "error"},
	{"error_container", "errorContainer"},
	{"outline", "outline"},
	{"outline_variant", "outlineVariant"},
	{"on_surface", "onSurface"},
	{"on_surface_variant", "onSurfaceVariant"},
	{"on_primary", "onPrimary"},
	{"on_primary_container", "onPrimaryContainer"},
	{"on_secondary", "onSecondary"},
	{"on_secondary_container", "onSecondaryContainer"},
	{"on_tertiary", "onTertiary"},
	{"on_tertiary_container", "onTertiaryContainer"},
	{"on_error", "onError"},
	{"on_error_container", "onErrorContainer"},
	{"shadow", "shadow"},
	{"scrim", "scrim"},
}

// matugenColorsJSON is the shell palette written to colors.json: the base16 keys
// the legacy reader consumes plus the camelCase Material 3 roles Theme.qml and
// Tokens.qml read, both from the one matugen palette.
func matugenColorsJSON(pal map[string]string) map[string]string {
	out := matugenBase16(pal)
	for _, kv := range matugenRoleKeys {
		if v := pal[kv[0]]; v != "" {
			out[kv[1]] = v
		}
	}
	return out
}

// matugenCarrier wraps the flat palette in the nested shape matugen's template
// engine expects (role.default.hex, role.hex, role.rgb, ...), plus an opaque
// _argb variant per colour for templates that need it (Qt).
func matugenCarrier(pal map[string]string) map[string]any {
	colors := make(map[string]any, len(pal)*2)
	put := func(name, hex string) {
		if hex == "" {
			return
		}
		stripped := strings.TrimPrefix(hex, "#")
		var r, g, b int64
		if len(stripped) == 6 {
			r, _ = strconv.ParseInt(stripped[0:2], 16, 0)
			g, _ = strconv.ParseInt(stripped[2:4], 16, 0)
			b, _ = strconv.ParseInt(stripped[4:6], 16, 0)
		}
		co := map[string]any{
			"hex":          hex,
			"hex_stripped": stripped,
			"red":          strconv.FormatInt(r, 10),
			"green":        strconv.FormatInt(g, 10),
			"blue":         strconv.FormatInt(b, 10),
			"rgb":          fmt.Sprintf("%d, %d, %d", r, g, b),
		}
		entry := map[string]any{"default": co, "dark": co, "light": co}
		for key, val := range co {
			entry[key] = val
		}
		colors[name] = entry
	}
	for k, v := range pal {
		put(k, v)
		put(k+"_argb", "#ff"+strings.TrimPrefix(v, "#"))
	}
	return map[string]any{"colors": colors}
}

// templateGroup maps a matugen template block name to its roster key, so one
// roster toggle (e.g. "gtk", "discord", "qt") governs every block that themes
// that app.
func templateGroup(block string) string {
	switch block {
	case "gtk3", "gtk4":
		return "gtk"
	case "vesktop", "equibop":
		return "discord"
	case "qt6ct":
		return "qt"
	case "qt5ct":
		return "qt5"
	case "hypr":
		return "hyprland"
	default:
		return block
	}
}

// filterMatugenConfig keeps the [config] preamble and only the [templates.X]
// blocks whose roster group `enabled` reports on, so the rendered set is exactly
// the roster the user opted into. A block runs from its header to the next
// header; its comments and post_hook ride with it.
func filterMatugenConfig(toml string, enabled func(group string) bool) string {
	var out []string
	keep := true // the [config] preamble always renders
	for _, ln := range strings.Split(toml, "\n") {
		t := strings.TrimSpace(ln)
		switch {
		case strings.HasPrefix(t, "[templates."):
			block := strings.TrimSuffix(strings.TrimPrefix(t, "[templates."), "]")
			keep = enabled(templateGroup(block))
		case strings.HasPrefix(t, "[config"):
			keep = true
		}
		if keep {
			out = append(out, ln)
		}
	}
	return strings.Join(out, "\n")
}

// matugenRenderTemplates fans the palette into the deployed templates. The core
// surface (config.toml: kitty, the Hyprland border, btop, Qt) always themes,
// per-app roster gated. The GTK / GUI-app suite (apps.toml) themes only when the
// app-suite toggle is on; off blanks the GTK stylesheets so those apps fall back
// to stock.
func matugenRenderTemplates(shell map[string]string, k matugenKnobs) {
	dir := matugenTemplateDir()
	matugenEnsureDirs()
	carrierPath := filepath.Join(matugenCacheHome(), "ryoku", "matugen-carrier.json")
	if err := writeJSONFile(carrierPath, matugenCarrier(shell)); err != nil {
		fmt.Fprintf(os.Stderr, "matugen carrier: %v\n", err)
		return
	}
	// A roster key the user explicitly turned off stays off; a group ABSENT from
	// their roster is one that shipped after they last saved it, and defaults on.
	// Absent-means-off would have kept every app added from here on dark for
	// everyone who had ever opened the appearance page.
	enabled := func(group string) bool {
		if v, ok := k.Templates[group]; ok {
			return v
		}
		return true
	}
	matugenRenderFiltered(filepath.Join(dir, "config.toml"), carrierPath, enabled)
	if k.ThemeRyokuApps {
		matugenRenderFiltered(filepath.Join(dir, "apps.toml"), carrierPath, enabled)
	} else {
		blankGtk(matugenConfigHome())
	}
}

// matugenRenderFiltered renders one matugen config with only its roster-enabled
// template blocks. The filtered config is staged in the cache so the shipped
// template map stays the single source of the destinations and post_hooks.
func matugenRenderFiltered(config, carrier string, enabled func(group string) bool) {
	b, err := os.ReadFile(config)
	if err != nil {
		return
	}
	active := filepath.Join(matugenCacheHome(), "ryoku", "active-"+filepath.Base(config))
	if err := os.WriteFile(active, []byte(filterMatugenConfig(string(b), enabled)), 0o644); err != nil {
		return
	}
	matugenRender(active, carrier)
}

// matugenRender runs one templating pass over a config, logging matugen's own
// output on failure. A missing config is skipped, not an error.
func matugenRender(config, carrier string) {
	if _, err := os.Stat(config); err != nil {
		return
	}
	if out, err := exec.Command("matugen", "-c", config, "json", carrier).CombinedOutput(); err != nil {
		fmt.Fprintf(os.Stderr, "matugen render %s: %v: %s\n", filepath.Base(config), err, strings.TrimSpace(string(out)))
	}
}

// runCommand / runCommandOutput are the process shims the reload and luminance
// steps go through, so a test can record the invocations without spawning
// anything.
var (
	runCommand = func(name string, args ...string) error {
		return exec.Command(name, args...).Run()
	}
	runCommandOutput = func(name string, args ...string) ([]byte, error) {
		return exec.Command(name, args...).Output()
	}
)

// matugenReload nudges the toolkits to re-read the regenerated configs: the
// libadwaita colour-scheme preference tracks light/dark, a gtk-theme flip makes
// running GTK apps re-read the stylesheet, and SIGUSR1 reloads kitty (its
// kitty.conf includes current-theme.conf). Hyprland is reloaded by the caller.
func matugenReload(mode string) {
	scheme := "prefer-dark"
	if mode == "light" {
		scheme = "prefer-light"
	}
	_ = runCommand("gsettings", "set", "org.gnome.desktop.interface", "color-scheme", scheme)
	matugenNudgeGtk()
	_ = runCommand("pkill", "-USR1", "-x", "kitty")
}

// matugenNudgeGtk flips the GTK theme name off and back, the standard live-reload
// signal, so a running GTK app re-reads the regenerated stylesheet.
func matugenNudgeGtk() {
	out, err := runCommandOutput("gsettings", "get", "org.gnome.desktop.interface", "gtk-theme")
	if err != nil {
		return
	}
	name := strings.Trim(strings.TrimSpace(string(out)), "'")
	if name == "" {
		return
	}
	_ = runCommand("gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", "")
	_ = runCommand("gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", name)
}

// matugenThemeSig fingerprints the settings frame's theme keys the pipeline
// depends on (the active theme name). The settings topic nudges the paint worker
// whenever this changes, so switching to or from a fixed named theme retunes the
// desktop. The scheme knobs live in matugen.json (watched separately), so they
// are not part of this signature.
func matugenThemeSig(frame []byte) string {
	var doc struct {
		Theme struct {
			Theme string `json:"theme"`
		} `json:"theme"`
	}
	if json.Unmarshal(frame, &doc) != nil {
		return ""
	}
	return doc.Theme.Theme
}

// watchMatugenKnobs retints the desktop whenever the knob store changes, so a Hub
// appearance save (which writes matugen.json and renders nothing itself) takes
// hold at once, exactly as a wallpaper change does. scheduleTheme coalesces, so
// a burst of rapid saves themes once. A poll is simpler and more robust across
// the Hub's rename-and-replace write than an inotify watch, at negligible idle
// cost. Runs for the life of the daemon.
func (d *daemon) watchMatugenKnobs() {
	path := matugenKnobsPath()
	var last time.Time
	if fi, err := os.Stat(path); err == nil {
		last = fi.ModTime()
	}
	for range time.Tick(500 * time.Millisecond) {
		fi, err := os.Stat(path)
		if err != nil {
			continue
		}
		if m := fi.ModTime(); !m.Equal(last) {
			last = m
			d.scheduleTheme()
		}
	}
}

// --- paths -----------------------------------------------------------------

func matugenConfigHome() string {
	if d := os.Getenv("XDG_CONFIG_HOME"); d != "" {
		return d
	}
	return filepath.Join(os.Getenv("HOME"), ".config")
}

func matugenCacheHome() string {
	if d := os.Getenv("XDG_CACHE_HOME"); d != "" {
		return d
	}
	return filepath.Join(os.Getenv("HOME"), ".cache")
}

func matugenDataHome() string {
	if d := os.Getenv("XDG_DATA_HOME"); d != "" {
		return d
	}
	return filepath.Join(os.Getenv("HOME"), ".local", "share")
}

func matugenTemplateDir() string { return filepath.Join(matugenConfigHome(), "matugen") }

// matugenKnobsPath is the one knob store the Hub appearance page and the daemon
// share.
func matugenKnobsPath() string {
	return filepath.Join(ryokuConfigDir(), "matugen.json")
}

// matugenColorsPath is the shell palette every Quickshell singleton watches. It
// lives under the ryoku cache dir; a single reader convention serves the matugen
// palette source the shell singletons watch.
func matugenColorsPath() string {
	return filepath.Join(matugenCacheHome(), "ryoku", "colors.json")
}

// matugenTonesPath is the tonal-ramp file beside it, for the surfaces that must
// choose a tone rather than consume one. Absent under a fixed named theme.
func matugenTonesPath() string {
	return filepath.Join(matugenCacheHome(), "ryoku", "tones.json")
}

// matugenEnsureDirs pre-creates the template output directories so matugen's own
// "folder doesn't exist" warnings stay out of the daemon log.
func matugenEnsureDirs() {
	cfg := matugenConfigHome()
	cache := matugenCacheHome()
	data := matugenDataHome()
	for _, d := range []string{
		filepath.Join(cache, "ryoku"),
		filepath.Join(cache, "matugen"),
		filepath.Join(cfg, "kitty"),
		filepath.Join(cfg, "btop", "themes"),
		filepath.Join(cfg, "qt6ct", "colors"),
		filepath.Join(cfg, "qt5ct", "colors"),
		filepath.Join(cfg, "gtk-3.0"),
		filepath.Join(cfg, "gtk-4.0"),
		filepath.Join(cfg, "vesktop", "themes"),
		filepath.Join(cfg, "equibop", "themes"),
		filepath.Join(cfg, "obs-studio", "themes"),
		filepath.Join(cfg, "zed", "themes"),
		filepath.Join(cfg, "heroic", "store", "styles"),
		filepath.Join(cfg, "cava"),
		filepath.Join(cfg, "fish", "conf.d"),
		filepath.Join(cfg, "yazi"),
		filepath.Join(cfg, "ghostty"),
		filepath.Join(cfg, "micro", "colorschemes"),
		filepath.Join(data, "TelegramDesktop", "tdata"),
		filepath.Join(os.Getenv("HOME"), ".steam", "steam", "steamui", "skins", "Material-Theme", "css", "main", "colors"),
	} {
		_ = os.MkdirAll(d, 0o755)
	}
}

// writeJSONFile writes v as indented JSON atomically (temp file then rename), so
// a subscriber watching the file never reads a half-written palette.
func writeJSONFile(path string, v any) error {
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	b, err := json.MarshalIndent(v, "", "  ")
	if err != nil {
		return err
	}
	b = append(b, '\n')
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, b, 0o644); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}
