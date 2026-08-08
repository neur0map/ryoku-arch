package main

import (
	"math"
	"testing"
)

// TestWallToneLstar pins the luminance -> L* mapping the whole smart-ink layer
// measures in. The QML side reimplements it, and a tone distance is only a
// contrast budget if both agree: mid gray must land near 53.6, not the 50 a
// gamma-encoded luma would give.
func TestWallToneLstar(t *testing.T) {
	cases := []struct {
		name    string
		r, g, b uint8
		want    float64
	}{
		{"black", 0, 0, 0, 0},
		{"white", 255, 255, 255, 100},
		{"mid gray", 128, 128, 128, 53.6},
	}
	for _, c := range cases {
		got := lstarFromY(relLuminance(c.r, c.g, c.b))
		if math.Abs(got-c.want) > 0.5 {
			t.Errorf("%s: L* = %.2f, want %.1f", c.name, got, c.want)
		}
	}
}

// TestParseMatugenTones proves the tonal ramps survive the same --json output
// the roles are read from, and that neutral_variant reaches QML under the
// camelCase name the role keys already use.
func TestParseMatugenTones(t *testing.T) {
	out := []byte(`{"colors":{},"palettes":{
		"primary":{"0":{"color":"#000000"},"40":{"color":"#96406d"},"80":{"color":"#ffafd3"}},
		"neutral_variant":{"50":{"color":"#7a7580"}},
		"empty":{}
	}}`)
	ramps := parseMatugenTones(out)
	if ramps == nil {
		t.Fatal("parseMatugenTones returned nil for a palette-bearing document")
	}
	if got := ramps["primary"]["40"]; got != "#96406d" {
		t.Errorf("primary tone 40 = %q, want #96406d", got)
	}
	if got := ramps["neutralVariant"]["50"]; got != "#7a7580" {
		t.Errorf("neutralVariant tone 50 = %q, want #7a7580", got)
	}
	if _, ok := ramps["empty"]; ok {
		t.Error("a ramp with no usable tones should be dropped, not published empty")
	}
	if parseMatugenTones([]byte(`{"colors":{}}`)) != nil {
		t.Error("a document with no palettes should return nil so the file is left alone")
	}
}
