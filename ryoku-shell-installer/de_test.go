package main

import (
	"strings"
	"testing"
)

func TestParseGnomeSources(t *testing.T) {
	l, v := parseGnomeSources(`[('xkb', 'us+dvorak'), ('xkb', 'fr'), ('ibus', 'anthy')]`)
	if l != "us" || v != "dvorak" {
		t.Fatalf("got %q %q", l, v)
	}
	l, v = parseGnomeSources(`[('ibus', 'anthy'), ('xkb', 'de')]`)
	if l != "de" || v != "" {
		t.Fatalf("ibus entries must be skipped: %q %q", l, v)
	}
	if l, _ = parseGnomeSources(`@a(ss) []`); l != "" {
		t.Fatalf("empty sources must salvage nothing, got %q", l)
	}
}

func TestParseGnomeOptions(t *testing.T) {
	if got := parseGnomeOptions(`['caps:ctrl_modifier', 'compose:ralt']`); got != "caps:ctrl_modifier,compose:ralt" {
		t.Fatalf("got %q", got)
	}
	if got := parseGnomeOptions(`@as []`); got != "" {
		t.Fatalf("empty options array must be empty, got %q", got)
	}
}

const monitorsXMLSample = `<monitors version="2">
  <configuration>
    <logicalmonitor>
      <x>1920</x><y>0</y>
      <scale>2</scale>
      <primary>yes</primary>
      <transform><rotation>left</rotation><flipped>no</flipped></transform>
      <monitor>
        <monitorspec><connector>HDMI-2</connector><vendor>SAM</vendor></monitorspec>
        <mode><width>1920</width><height>1080</height><rate>30.000</rate></mode>
      </monitor>
    </logicalmonitor>
    <logicalmonitor>
      <x>0</x><y>0</y>
      <scale>1</scale>
      <monitor>
        <monitorspec><connector>eDP-1</connector></monitorspec>
        <mode><width>2560</width><height>1600</height><rate>60.001</rate></mode>
      </monitor>
    </logicalmonitor>
    <disabled><monitorspec><connector>DP-3</connector></monitorspec></disabled>
  </configuration>
</monitors>`

func TestParseMonitorsXML(t *testing.T) {
	outs := parseMonitorsXML([]byte(monitorsXMLSample))
	if len(outs) != 3 {
		t.Fatalf("want 2 monitors + 1 disabled, got %+v", outs)
	}
	hdmi := outs[0]
	if hdmi.name != "HDMI-2" || hdmi.mode != "1920x1080@30.000" || hdmi.position != "1920x0" ||
		hdmi.scale != "2" || hdmi.transform != 1 {
		t.Fatalf("HDMI-2 parsed wrong: %+v", hdmi)
	}
	if outs[1].name != "eDP-1" || outs[1].scale != "" || outs[1].mode != "2560x1600@60.001" {
		t.Fatalf("eDP-1 parsed wrong: %+v", outs[1])
	}
	if !outs[2].off || outs[2].name != "DP-3" {
		t.Fatalf("disabled connector missed: %+v", outs[2])
	}
	// two configuration blocks: matching the right one is guesswork, skip.
	two := strings.Replace(monitorsXMLSample, "</monitors>",
		"<configuration></configuration></monitors>", 1)
	if got := parseMonitorsXML([]byte(two)); got != nil {
		t.Fatalf("multi-config files must not be salvaged: %+v", got)
	}
}

func TestParseKxkbrc(t *testing.T) {
	sample := "[Layout]\nLayoutList=us,de\nVariantList=,neo\nOptions=grp:alt_shift_toggle,caps:escape\nResetOldOptions=true\nUse=true\n"
	l, v, o, ok := parseKxkbrc(sample)
	if !ok || l != "us,de" || v != ",neo" || o != "grp:alt_shift_toggle,caps:escape" {
		t.Fatalf("got %q %q %q ok=%v", l, v, o, ok)
	}
	if _, _, _, ok := parseKxkbrc(strings.Replace(sample, "Use=true", "Use=false", 1)); ok {
		t.Fatal("Use=false means KDE follows the system layout, nothing to salvage")
	}
	if _, _, _, ok := parseKxkbrc("[Layout]\nLayoutList=us\n"); ok {
		t.Fatal("absent Use= must not salvage")
	}
	// all-empty variant slots collapse to no variant.
	l, v, _, ok = parseKxkbrc("[Layout]\nUse=true\nLayoutList=us,ru\nVariantList=,\n")
	if !ok || l != "us,ru" || v != "" {
		t.Fatalf("empty variants kept: %q %q", l, v)
	}
}

const kwinSample = `[
  {"name": "outputs", "data": [
    {"connectorName": "DP-2",
     "mode": {"width": 2560, "height": 1440, "refreshRate": 165004},
     "scale": 1.25, "transform": "Rotated90", "vrrPolicy": "Always"},
    {"connectorName": "HDMI-A-1",
     "mode": {"width": 1920, "height": 1080, "refreshRate": 60000},
     "scale": 1, "transform": "Normal", "vrrPolicy": "Never"}
  ]}
]`

func TestParseKwinOutputs(t *testing.T) {
	outs := parseKwinOutputs([]byte(kwinSample))
	if len(outs) != 2 {
		t.Fatalf("want both outputs, got %+v", outs)
	}
	dp := outs[0]
	if dp.name != "DP-2" || dp.mode != "2560x1440@165.004" || dp.scale != "1.25" ||
		dp.transform != 1 || dp.vrr != 1 {
		t.Fatalf("DP-2 parsed wrong: %+v", dp)
	}
	if outs[1].scale != "" || outs[1].transform != 0 || outs[1].vrr != 0 || outs[1].mode != "1920x1080@60" {
		t.Fatalf("HDMI-A-1 parsed wrong: %+v", outs[1])
	}
	if parseKwinOutputs([]byte("not json")) != nil {
		t.Fatal("bad json must salvage nothing")
	}
}

func TestThemeCurrent(t *testing.T) {
	kde := "[General]\nHaltCommand=x\n[Theme]\nCurrent=breeze\n"
	ryoku := "[Theme]\nCurrent=ryoku\n"
	if got := themeCurrent(kde, themeCurrent(ryoku, "")); got != "breeze" {
		t.Fatalf("later file must win, got %q", got)
	}
	if got := themeCurrent(ryoku, themeCurrent(kde, "")); got != "ryoku" {
		t.Fatalf("later file must win, got %q", got)
	}
	if got := themeCurrent("[Autologin]\nSession=plasma\n", "prev"); got != "prev" {
		t.Fatalf("no theme section keeps the previous winner, got %q", got)
	}
}
