package main

// de.go carries keyboard and monitor intent over from GNOME and KDE stores,
// mirroring the niri salvage model: parse intent in detect(), render pins in
// stepConfigs. coexistence policy: a desktop environment is never
// uninstalled and its session-scoped services (gsd-*, plasma-*) are never
// touched; they are RefuseManualStart units bound to their own session and
// cannot leak into a Ryoku session. the old desktop stays selectable at the
// login screen.

import (
	"encoding/json"
	"encoding/xml"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

// installed desktop environments; package presence is the honest signal, an
// enabled DM only shows the default one.
var desktopPkgs = []struct{ pkg, name string }{
	{"gnome-shell", "GNOME"},
	{"plasma-desktop", "KDE Plasma"},
	{"cinnamon", "Cinnamon"},
	{"xfce4-session", "Xfce"},
}

func detectDesktops() []string {
	var found []string
	for _, d := range desktopPkgs {
		if pacmanHas(d.pkg) {
			found = append(found, d.name)
		}
	}
	return found
}

// ---- GNOME keyboard (gsettings, dconf is a binary blob) ----

// gsettings output for input-sources is GVariant text like
// [('xkb', 'us+dvorak'), ('ibus', 'anthy')]; ibus entries are input methods
// and carry no xkb layout.
var gnomeXkbTupleRe = regexp.MustCompile(`\('xkb',\s*'([^']+)'\)`)
var gnomeOptRe = regexp.MustCompile(`'([^']+)'`)

// parseGnomeSources takes the first xkb tuple; layout and variant are joined
// with + in the source id.
func parseGnomeSources(text string) (layout, variant string) {
	m := gnomeXkbTupleRe.FindStringSubmatch(text)
	if m == nil {
		return "", ""
	}
	layout, variant, _ = strings.Cut(m[1], "+")
	return layout, variant
}

func parseGnomeOptions(text string) string {
	if strings.Contains(text, "@as []") {
		return ""
	}
	var opts []string
	for _, m := range gnomeOptRe.FindAllStringSubmatch(text, -1) {
		opts = append(opts, m[1])
	}
	return strings.Join(opts, ",")
}

// gnomeKeyboard shells out to gsettings as the user; reads work without a
// session bus, they go straight to the dconf db.
func gnomeKeyboard() (layout, variant, options string) {
	if !has("gsettings") {
		return
	}
	layout, variant = parseGnomeSources(out("gsettings", "get", "org.gnome.desktop.input-sources", "sources"))
	if layout == "" {
		return
	}
	options = parseGnomeOptions(out("gsettings", "get", "org.gnome.desktop.input-sources", "xkb-options"))
	return
}

// ---- GNOME monitors.xml (mutter, version="2" since GNOME 3.26) ----

type monitorsXML struct {
	Version string `xml:"version,attr"`
	Configs []struct {
		Logical []struct {
			X         string `xml:"x"`
			Y         string `xml:"y"`
			Scale     string `xml:"scale"`
			Transform struct {
				Rotation string `xml:"rotation"`
				Flipped  string `xml:"flipped"`
			} `xml:"transform"`
			Monitor struct {
				Spec struct {
					Connector string `xml:"connector"`
				} `xml:"monitorspec"`
				Mode struct {
					Width  string `xml:"width"`
					Height string `xml:"height"`
					Rate   string `xml:"rate"`
				} `xml:"mode"`
			} `xml:"monitor"`
		} `xml:"logicalmonitor"`
		Disabled []struct {
			Connector string `xml:"connector"`
		} `xml:"disabled>monitorspec"`
	} `xml:"configuration"`
}

// mutter rotation names are counter-clockwise: left = wl_output 90 =
// hyprland transform 1. flipped=yes adds the +4 flipped variants.
var mutterRotation = map[string]int{"left": 1, "upside_down": 2, "right": 3}

// parseMonitorsXML salvages only when there is exactly one configuration
// block; picking between per-monitor-set configs is guesswork (same
// conservatism as the niri salvage).
func parseMonitorsXML(b []byte) []niriOutput {
	var mx monitorsXML
	if err := xml.Unmarshal(b, &mx); err != nil || len(mx.Configs) != 1 {
		return nil
	}
	var outs []niriOutput
	cfg := mx.Configs[0]
	for _, lm := range cfg.Logical {
		o := niriOutput{name: strings.TrimSpace(lm.Monitor.Spec.Connector)}
		if o.name == "" {
			continue
		}
		w, h := strings.TrimSpace(lm.Monitor.Mode.Width), strings.TrimSpace(lm.Monitor.Mode.Height)
		if w != "" && h != "" {
			o.mode = w + "x" + h
			if r := strings.TrimSpace(lm.Monitor.Mode.Rate); r != "" {
				o.mode += "@" + r
			}
		}
		x, y := strings.TrimSpace(lm.X), strings.TrimSpace(lm.Y)
		if x != "" && y != "" {
			o.position = x + "x" + y
		}
		o.scale = strings.TrimSpace(lm.Scale)
		if o.scale == "1" {
			o.scale = "" // default, no pin value needed
		}
		o.transform = mutterRotation[lm.Transform.Rotation]
		if strings.EqualFold(lm.Transform.Flipped, "yes") {
			o.transform += 4
		}
		if o.meaningful() {
			outs = append(outs, o)
		}
	}
	for _, d := range cfg.Disabled {
		if c := strings.TrimSpace(d.Connector); c != "" {
			outs = append(outs, niriOutput{name: c, off: true})
		}
	}
	return outs
}

// ---- KDE keyboard (kxkbrc) ----

// parseKxkbrc reads the [Layout] section. Use=true is the gate: without it
// KDE follows the system (localectl) layout and there is nothing to salvage.
// VariantList is positional against LayoutList, commas must survive.
func parseKxkbrc(text string) (layout, variant, options string, ok bool) {
	section := ""
	use := false
	for _, ln := range strings.Split(text, "\n") {
		t := strings.TrimSpace(ln)
		if strings.HasPrefix(t, "[") {
			section = t
			continue
		}
		if section != "[Layout]" {
			continue
		}
		k, v, found := strings.Cut(t, "=")
		if !found {
			continue
		}
		v = strings.TrimSpace(v)
		switch strings.TrimSpace(k) {
		case "Use":
			use = v == "true"
		case "LayoutList":
			layout = v
		case "VariantList":
			variant = v
		case "Options":
			options = v
		}
	}
	if !use || layout == "" {
		return "", "", "", false
	}
	if strings.Trim(variant, ",") == "" {
		variant = ""
	}
	return layout, variant, options, true
}

// ---- KDE monitors (Plasma 6 kwinoutputconfig.json) ----

// same wl_output enum as everywhere else, just spelled out.
var kwinTransform = map[string]int{
	"Normal": 0, "Rotated90": 1, "Rotated180": 2, "Rotated270": 3,
	"Flipped": 4, "Flipped90": 5, "Flipped180": 6, "Flipped270": 7,
}

var kwinVrr = map[string]int{"Never": 0, "Always": 1, "Automatic": 2}

// parseKwinOutputs walks the JSON generically and collects every object with
// a connectorName; the store's nesting has shifted between Plasma releases
// and only the per-output fields are stable. positions live in the setups
// section keyed by output index and are left to autoscale.
func parseKwinOutputs(b []byte) []niriOutput {
	var root any
	if err := json.Unmarshal(b, &root); err != nil {
		return nil
	}
	byName := map[string]int{}
	var outs []niriOutput
	var walk func(v any)
	walk = func(v any) {
		switch node := v.(type) {
		case []any:
			for _, it := range node {
				walk(it)
			}
		case map[string]any:
			if name, _ := node["connectorName"].(string); name != "" {
				o := kwinOutput(name, node)
				if o.meaningful() {
					if at, dup := byName[o.name]; dup {
						outs[at] = o
					} else {
						byName[o.name] = len(outs)
						outs = append(outs, o)
					}
				}
			}
			for _, it := range node {
				walk(it)
			}
		}
	}
	walk(root)
	return outs
}

func kwinOutput(name string, node map[string]any) niriOutput {
	o := niriOutput{name: name}
	if mode, ok := node["mode"].(map[string]any); ok {
		w, wok := mode["width"].(float64)
		h, hok := mode["height"].(float64)
		if wok && hok && w > 0 && h > 0 {
			o.mode = strconv.Itoa(int(w)) + "x" + strconv.Itoa(int(h))
			if r, ok := mode["refreshRate"].(float64); ok && r > 0 {
				// stored in mHz
				o.mode += "@" + strconv.FormatFloat(r/1000, 'g', -1, 64)
			}
		}
	}
	if s, ok := node["scale"].(float64); ok && s > 0 && s != 1 {
		o.scale = strconv.FormatFloat(s, 'g', -1, 64)
	}
	if t, ok := node["transform"].(string); ok {
		o.transform = kwinTransform[t]
	}
	if v, ok := node["vrrPolicy"].(string); ok {
		o.vrr = kwinVrr[v]
	}
	return o
}

// deSalvage fills whatever keyboard and monitor intent is still missing from
// the GNOME/KDE stores. compositor configs (hyprland, niri, sway) already
// had their turn; DE stores are the fallback for boxes coming from a full
// desktop.
func (f *facts) deSalvage() {
	kde := hasDesktop(f.desktops, "KDE Plasma")
	gnome := hasDesktop(f.desktops, "GNOME")
	if f.kbLayout == "" && kde {
		if b, err := os.ReadFile(filepath.Join(f.homeDir, ".config/kxkbrc")); err == nil {
			if l, v, o, ok := parseKxkbrc(string(b)); ok {
				f.kbLayout, f.kbVariant, f.kbOptions, f.kbSource = l, v, o, "KDE"
			}
		}
	}
	if f.kbLayout == "" && gnome {
		if l, v, o := gnomeKeyboard(); l != "" {
			f.kbLayout, f.kbVariant, f.kbOptions, f.kbSource = l, v, o, "GNOME"
		}
	}
	if len(f.monOutputs) == 0 && kde {
		if b, err := os.ReadFile(filepath.Join(f.homeDir, ".config/kwinoutputconfig.json")); err == nil {
			if outs := parseKwinOutputs(b); len(outs) > 0 {
				f.monOutputs, f.monSource = outs, "KDE"
			}
		}
	}
	if len(f.monOutputs) == 0 && gnome {
		if b, err := os.ReadFile(filepath.Join(f.homeDir, ".config/monitors.xml")); err == nil {
			if outs := parseMonitorsXML(b); len(outs) > 0 {
				f.monOutputs, f.monSource = outs, "GNOME"
			}
		}
	}
}

// themeCurrent folds one config file's [Theme] Current= over the previous
// winner; SDDM reads /etc/sddm.conf then conf.d in lexical order and later
// files win per key.
func themeCurrent(text, prev string) string {
	section := ""
	for _, ln := range strings.Split(text, "\n") {
		t := strings.TrimSpace(ln)
		if strings.HasPrefix(t, "[") {
			section = t
			continue
		}
		if section != "[Theme]" {
			continue
		}
		if v, ok := strings.CutPrefix(t, "Current="); ok {
			prev = strings.TrimSpace(v)
		}
	}
	return prev
}

// effectiveSDDMTheme resolves which greeter theme SDDM will actually use.
func effectiveSDDMTheme() string {
	files := []string{"/etc/sddm.conf"}
	if m, err := filepath.Glob("/etc/sddm.conf.d/*"); err == nil {
		files = append(files, m...) // glob output is sorted
	}
	theme := ""
	for _, f := range files {
		if b, err := os.ReadFile(f); err == nil {
			theme = themeCurrent(string(b), theme)
		}
	}
	return theme
}

func hasDesktop(desktops []string, name string) bool {
	for _, d := range desktops {
		if d == name {
			return true
		}
	}
	return false
}
