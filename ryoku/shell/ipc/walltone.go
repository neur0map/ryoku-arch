package main

import (
	"fmt"
	"math"
	"path/filepath"
)

// walltone.go describes the wallpaper the way a Material role describes a
// panel: CIE L* per cell on an 8x8 grid, row-major from the top-left, plus the
// frame mean. Surfaces that float on the picture (the visualiser, a bare
// desktop widget) have no panel to contrast against, so without this they take
// whatever tone the scheme picked for a surface that is not there -- near-black
// on a light scheme, which is why the spectrum drew black bars.
//
// L* is the unit because a tone distance is a contrast budget in it: 40 apart
// clears 3:1, 50 apart clears 4.5:1. Material 3 builds its tonal palettes on
// the same rule, so this and the ramps agree by construction.

const wallToneCols, wallToneRows = 8, 8

// wallpaperTonePath is the map every wallpaper-floating surface watches.
func wallpaperTonePath() string {
	return filepath.Join(matugenCacheHome(), "ryoku", "wallpaper-tone.json")
}

// writeWallpaperTone samples pic into the map. A video is measured through the
// same still the palette is generated from, so both describe one frame. On
// failure the previous map stands: last wallpaper's tones still beat none.
func writeWallpaperTone(pic string) {
	if pic == "" || !isFile(pic) {
		return
	}
	if isVideo(pic) {
		if pic = liveFrame(pic); pic == "" {
			return
		}
	}
	grid, ok := wallToneGrid(pic)
	if !ok {
		return
	}
	var sum float64
	for _, v := range grid {
		sum += v
	}
	_ = writeJSONFile(wallpaperTonePath(), map[string]any{
		"cols":  wallToneCols,
		"rows":  wallToneRows,
		"lstar": round2(sum / float64(len(grid))),
		"grid":  grid,
	})
}

// wallToneGrid area-averages the image to one pixel per cell and returns each
// cell's L*. ffmpeg does the scaling, so png / jpeg / webp and a sampled video
// still all resolve through one path rather than splitting on what the stdlib
// decoders happen to read.
func wallToneGrid(img string) ([]float64, bool) {
	out, err := runCommandOutput("ffmpeg", "-v", "error", "-i", img,
		"-vf", fmt.Sprintf("scale=%d:%d:flags=area", wallToneCols, wallToneRows),
		"-frames:v", "1", "-pix_fmt", "rgb24", "-f", "rawvideo", "-")
	n := wallToneCols * wallToneRows
	if err != nil || len(out) < n*3 {
		return nil, false
	}
	grid := make([]float64, n)
	for i := range grid {
		grid[i] = round2(lstarFromY(relLuminance(out[i*3], out[i*3+1], out[i*3+2])))
	}
	return grid, true
}

// relLuminance is WCAG relative luminance: sRGB channels linearised, then the
// CIE Y weights. Not the 0.299/0.587/0.114 luma the smart light/dark pick uses;
// that runs on gamma-encoded values and misjudges the mid tones where a
// contrast call is close.
func relLuminance(r8, g8, b8 uint8) float64 {
	lin := func(v uint8) float64 {
		u := float64(v) / 255
		if u <= 0.04045 {
			return u / 12.92
		}
		return math.Pow((u+0.055)/1.055, 2.4)
	}
	return 0.2126*lin(r8) + 0.7152*lin(g8) + 0.0722*lin(b8)
}

// lstarFromY maps relative luminance to CIE L* (0..100).
func lstarFromY(y float64) float64 {
	if y <= 216.0/24389.0 {
		return y * 24389.0 / 27.0
	}
	return math.Cbrt(y)*116.0 - 16.0
}

func round2(v float64) float64 { return math.Round(v*100) / 100 }
