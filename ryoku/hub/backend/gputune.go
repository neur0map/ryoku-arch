package main

// gputune.go: `ryoku-hub gpu tune ...`, the per-session GPU tuning surface the
// Hub GPU page drives. Everything here is runtime state (sysfs / nvidia-smi):
// it applies live and is gone on the next reboot, which is the whole safety
// model. A snapper snapshot would not help (it captures the filesystem, not GPU
// runtime state), so the backup is `reset` or a reboot, nothing persistent.
//
// The design mirrors hwcaps.go: buildTunables() is a pure function of gathered
// inputs, unit-tested across hardware shapes; detectTune() does the messy live
// probing. Nothing is assumed about the hardware. A knob appears only if the
// machine actually exposes it, so the same binary is correct on an Intel laptop,
// a single-GPU desktop, or this AMD+NVIDIA box.

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

// Tunable = one knob the page can render. kind picks the control:
// slider (min/max/current + unit) or segment (options + value).
type Tunable struct {
	GPU     string   `json:"gpu"`   // pci slot, or "platform"
	ID      string   `json:"id"`    // power_limit | perf_level | ...
	Label   string   `json:"label"` // human label
	Kind    string   `json:"kind"`  // slider | segment | toggle
	Unit    string   `json:"unit,omitempty"`
	Min     float64  `json:"min,omitempty"`
	Max     float64  `json:"max,omitempty"`
	Current float64  `json:"current,omitempty"`
	Options []string `json:"options,omitempty"`
	Value   string   `json:"value,omitempty"` // segment/toggle current
	Risk    string   `json:"risk"`            // safe | advanced
	Src     string   `json:"src"`             // source tag (sysfs path or cmd)
}

// odRange = the pp_od_clk_voltage sclk overdrive window and its current top.
type odRange struct {
	minMHz, maxMHz  int // OD_RANGE SCLK bounds
	curMin, curMax  int // OD_SCLK level 0 / 1
}

// amdCap = the amdgpu hwmon power cap, microwatts as sysfs reports it.
type amdCap struct {
	curUW, maxUW, defUW int
}

// nvInfo = what nvidia-smi reports for one NVIDIA GPU.
type nvInfo struct {
	powerSupported                          bool
	powerMinW, powerMaxW, powerCurW, powerDefW float64
	persistence                             bool
	clockMaxGr                              int
	clockCurGr                              int
}

// gpuProbe = one GPU as the tuner sees it: identity from `ryoku-gpu detect`
// plus whatever knobs its driver exposes on this box (nil/zero when absent).
type gpuProbe struct {
	slot, card, driver, model, class string
	amdPerfLevel                     string   // "" if absent
	amdCap                           *amdCap  // nil if no power1_cap
	amdOD                            *odRange // nil if overdrive locked
	amdFan                           bool     // pwm1_enable present
	intelMinMHz, intelMaxMHz, intelRP0 int    // 0 if not Intel/absent
	nv                               *nvInfo  // nil for non-nvidia
}

type platformProfile struct {
	choices []string
	current string
}

type tuneInputs struct {
	gpus     []gpuProbe
	platform *platformProfile
}

func runGpuTune(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("gpu tune needs caps|get|set|reset")
	}
	switch args[0] {
	case "caps", "get":
		return printJSON(buildTunables(detectTune()))
	case "set":
		if len(args) < 4 {
			return fmt.Errorf("gpu tune set needs <gpu> <id> <value>")
		}
		return tuneSet(args[1], args[2], args[3])
	case "reset":
		gpu := ""
		if len(args) > 1 {
			gpu = args[1]
		}
		return tuneReset(gpu)
	case "preset":
		return runGpuPreset(args[1:])
	default:
		return fmt.Errorf("gpu tune needs caps|get|set|reset|preset")
	}
}

// ── the pure builder: gathered inputs -> the knob list ──────────────────────

func buildTunables(in tuneInputs) []Tunable {
	var out []Tunable
	for _, g := range in.gpus {
		if g.nv != nil {
			out = append(out, nvidiaTunables(g)...)
		}
		if g.driver == "amdgpu" {
			out = append(out, amdTunables(g)...)
		}
		if g.driver == "i915" || g.driver == "xe" {
			out = append(out, intelTunables(g)...)
		}
	}
	if in.platform != nil && len(in.platform.choices) > 0 {
		out = append(out, Tunable{
			GPU: "platform", ID: "thermal", Label: "Thermal profile",
			Kind: "segment", Options: in.platform.choices,
			Value: in.platform.current, Risk: "safe",
			Src: "acpi/platform_profile",
		})
	}
	return out
}

func nvidiaTunables(g gpuProbe) []Tunable {
	var out []Tunable
	nv := g.nv
	if nv.powerSupported && nv.powerMaxW > nv.powerMinW {
		out = append(out, Tunable{
			GPU: g.slot, ID: "power_limit", Label: "Power limit",
			Kind: "slider", Unit: "W",
			Min: nv.powerMinW, Max: nv.powerMaxW, Current: nv.powerCurW,
			Risk: "safe", Src: "nvidia-smi -pl",
		})
	}
	out = append(out, Tunable{
		GPU: g.slot, ID: "persistence", Label: "Persistence mode",
		Kind: "toggle", Value: boolStr(nv.persistence),
		Risk: "safe", Src: "nvidia-smi -pm",
	})
	if nv.clockMaxGr > 0 {
		out = append(out, Tunable{
			GPU: g.slot, ID: "clock_lock", Label: "Max core clock",
			Kind: "slider", Unit: "MHz",
			Min: 300, Max: float64(nv.clockMaxGr), Current: float64(nv.clockCurGr),
			Risk: "advanced", Src: "nvidia-smi -lgc",
		})
	}
	return out
}

func amdTunables(g gpuProbe) []Tunable {
	var out []Tunable
	if g.amdPerfLevel != "" {
		out = append(out, Tunable{
			GPU: g.slot, ID: "perf_level", Label: "Performance level",
			Kind: "segment", Options: []string{"auto", "low", "high"},
			Value: normalizePerf(g.amdPerfLevel), Risk: "safe",
			Src: "power_dpm_force_performance_level",
		})
	}
	if g.amdCap != nil && g.amdCap.maxUW > 0 {
		out = append(out, Tunable{
			GPU: g.slot, ID: "power_cap", Label: "Power cap",
			Kind: "slider", Unit: "W",
			Min: 1, Max: float64(g.amdCap.maxUW) / 1e6,
			Current: float64(g.amdCap.curUW) / 1e6,
			Risk:    "safe", Src: "hwmon/power1_cap",
		})
	}
	if g.amdOD != nil && g.amdOD.maxMHz > g.amdOD.minMHz {
		out = append(out, Tunable{
			GPU: g.slot, ID: "sclk_od", Label: "Max GPU clock",
			Kind: "slider", Unit: "MHz",
			Min: float64(g.amdOD.minMHz), Max: float64(g.amdOD.maxMHz),
			Current: float64(g.amdOD.curMax),
			Risk:    "advanced", Src: "pp_od_clk_voltage",
		})
	}
	if g.amdFan {
		out = append(out, Tunable{
			GPU: g.slot, ID: "fan_pct", Label: "Fan speed",
			Kind: "slider", Unit: "%", Min: 0, Max: 100, Current: 0,
			Risk: "advanced", Src: "hwmon/pwm1",
		})
	}
	return out
}

func intelTunables(g gpuProbe) []Tunable {
	if g.intelMaxMHz <= 0 {
		return nil
	}
	top := g.intelRP0
	if top <= 0 {
		top = g.intelMaxMHz
	}
	return []Tunable{{
		GPU: g.slot, ID: "gt_freq", Label: "Max GPU clock",
		Kind: "slider", Unit: "MHz",
		Min: float64(g.intelMinMHz), Max: float64(top), Current: float64(g.intelMaxMHz),
		Risk: "advanced", Src: "gt_max_freq_mhz",
	}}
}

// ── live probing ────────────────────────────────────────────────────────────

func detectTune() tuneInputs {
	root := sysfsRoot()
	in := tuneInputs{}
	recs, err := gpuRecordsFromTool()
	if err == nil {
		for _, r := range recs {
			g := gpuProbe{
				slot: r.Slot, card: r.Card, driver: r.Driver,
				model: prettyModel(r.Model), class: r.Class,
			}
			switch r.Driver {
			case "amdgpu":
				readAMD(root, &g)
			case "i915", "xe":
				readIntel(root, &g)
			case "nvidia":
				g.nv = readNvidia(r.Slot)
			}
			in.gpus = append(in.gpus, g)
		}
	}
	in.platform = readPlatform(root)
	return in
}

func amdDevDir(root, card string) string {
	return filepath.Join(root, "sys/class/drm", card, "device")
}

func readAMD(root string, g *gpuProbe) {
	dev := amdDevDir(root, g.card)
	g.amdPerfLevel = readTrim(filepath.Join(dev, "power_dpm_force_performance_level"))
	if od := parseOD(readFile(filepath.Join(dev, "pp_od_clk_voltage"))); od != nil {
		g.amdOD = od
	}
	// hwmon knobs live one level down under an opaque hwmonN dir.
	if hw := firstHwmon(dev); hw != "" {
		cur := atoiTrim(readTrim(filepath.Join(hw, "power1_cap")))
		max := atoiTrim(readTrim(filepath.Join(hw, "power1_cap_max")))
		def := atoiTrim(readTrim(filepath.Join(hw, "power1_cap_default")))
		if max > 0 {
			g.amdCap = &amdCap{curUW: cur, maxUW: max, defUW: def}
		}
		if fileExists(filepath.Join(hw, "pwm1_enable")) {
			g.amdFan = true
		}
	}
}

func readIntel(root string, g *gpuProbe) {
	dev := amdDevDir(root, g.card) // same /sys/class/drm/<card>/device layout
	g.intelMinMHz = atoiTrim(readTrim(filepath.Join(dev, "gt_min_freq_mhz")))
	g.intelMaxMHz = atoiTrim(readTrim(filepath.Join(dev, "gt_max_freq_mhz")))
	g.intelRP0 = atoiTrim(readTrim(filepath.Join(dev, "gt_RP0_freq_mhz")))
}

// readNvidia asks nvidia-smi one CSV line for this GPU. Any failure returns a
// zero nvInfo with powerSupported false, so the knob simply does not appear.
func readNvidia(slot string) *nvInfo {
	nv := &nvInfo{}
	out, err := exec.Command("nvidia-smi", "-i", slot,
		"--query-gpu=power.management,power.limit,power.min_limit,power.max_limit,power.default_limit,persistence_mode,clocks.current.graphics,clocks.max.graphics",
		"--format=csv,noheader,nounits").Output()
	if err != nil {
		return nv
	}
	f := strings.Split(strings.TrimSpace(string(out)), ",")
	for i := range f {
		f[i] = strings.TrimSpace(f[i])
	}
	if len(f) < 8 {
		return nv
	}
	nv.powerSupported = strings.EqualFold(f[0], "Supported")
	nv.powerCurW = atofTrim(f[1])
	nv.powerMinW = atofTrim(f[2])
	nv.powerMaxW = atofTrim(f[3])
	nv.powerDefW = atofTrim(f[4])
	nv.persistence = strings.EqualFold(f[5], "Enabled")
	nv.clockCurGr = atoiTrim(f[6])
	nv.clockMaxGr = atoiTrim(f[7])
	return nv
}

func readPlatform(root string) *platformProfile {
	choices := strings.Fields(readTrim(filepath.Join(root, "sys/firmware/acpi/platform_profile_choices")))
	cur := readTrim(filepath.Join(root, "sys/firmware/acpi/platform_profile"))
	if len(choices) == 0 {
		return nil
	}
	return &platformProfile{choices: choices, current: cur}
}

// ── apply: set one knob live, escalating to root for the write ──────────────

func tuneSet(gpu, id, value string) error {
	in := detectTune()
	t := findTunable(buildTunables(in), gpu, id)
	if t == nil {
		return fmt.Errorf("no tunable %q on %s (this hardware does not expose it)", id, gpu)
	}
	// Validate + clamp against the probed envelope before any privileged write.
	if t.Kind == "segment" {
		if !inList(t.Options, value) {
			return fmt.Errorf("%s must be one of %s", id, strings.Join(t.Options, "|"))
		}
	} else {
		v, err := strconv.ParseFloat(value, 64)
		if err != nil {
			return fmt.Errorf("%s needs a number", id)
		}
		value = strconv.FormatFloat(clampf(v, t.Min, t.Max), 'f', -1, 64)
	}
	if os.Geteuid() != 0 {
		return escalateSelf("gpu", "tune", "set", gpu, id, value)
	}
	if err := applyKnob(in, gpu, id, value); err != nil {
		return err
	}
	return printJSON(map[string]string{"gpu": gpu, "id": id, "value": value})
}

func tuneReset(gpu string) error {
	if os.Geteuid() != 0 {
		if gpu == "" {
			return escalateSelf("gpu", "tune", "reset")
		}
		return escalateSelf("gpu", "tune", "reset", gpu)
	}
	in := detectTune()
	for _, g := range in.gpus {
		if gpu != "" && g.slot != gpu {
			continue
		}
		resetGPU(g)
	}
	if (gpu == "" || gpu == "platform") && in.platform != nil {
		// no factory default is exported; leave the profile as the firmware set
		// it. A reboot restores it. Nothing to do here beyond the GPUs.
	}
	return printJSON(map[string]string{"reset": orAll(gpu)})
}

// applyKnob dispatches one validated write. Runs as root (tuneSet escalated).
func applyKnob(in tuneInputs, gpu, id, value string) error {
	if gpu == "platform" {
		return writeSysfs(filepath.Join(sysfsRoot(), "sys/firmware/acpi/platform_profile"), value)
	}
	g := findGPU(in.gpus, gpu)
	if g == nil {
		return fmt.Errorf("unknown gpu %s", gpu)
	}
	dev := amdDevDir(sysfsRoot(), g.card)
	switch id {
	case "power_limit":
		return runErr("nvidia-smi", "-i", g.slot, "-pl", trimDot(value))
	case "persistence":
		return runErr("nvidia-smi", "-pm", boolNum(value))
	case "clock_lock":
		return runErr("nvidia-smi", "-i", g.slot, "-lgc", "0,"+trimDot(value))
	case "perf_level":
		return writeSysfs(filepath.Join(dev, "power_dpm_force_performance_level"), value)
	case "power_cap":
		uw := int(atofTrim(value) * 1e6)
		return writeSysfs(firstHwmon(dev)+"/power1_cap", strconv.Itoa(uw))
	case "sclk_od":
		return amdSetMaxSclk(dev, trimDot(value))
	case "fan_pct":
		return amdSetFan(dev, atoiTrim(trimDot(value)))
	}
	return fmt.Errorf("cannot apply %s", id)
}

func resetGPU(g gpuProbe) {
	dev := amdDevDir(sysfsRoot(), g.card)
	switch g.driver {
	case "nvidia":
		if g.nv != nil && g.nv.powerDefW > 0 {
			run("nvidia-smi", "-i", g.slot, "-pl", strconv.Itoa(int(g.nv.powerDefW)))
		}
		run("nvidia-smi", "-i", g.slot, "-rgc")
		run("nvidia-smi", "-i", g.slot, "-rmc")
		run("nvidia-smi", "-pm", "0")
	case "amdgpu":
		if g.amdOD != nil {
			_ = writeSysfs(filepath.Join(dev, "pp_od_clk_voltage"), "r")
			_ = writeSysfs(filepath.Join(dev, "pp_od_clk_voltage"), "c")
		}
		if g.amdFan {
			_ = writeSysfs(firstHwmon(dev)+"/pwm1_enable", "2") // 2 = auto
		}
		if g.amdCap != nil && g.amdCap.defUW > 0 {
			_ = writeSysfs(firstHwmon(dev)+"/power1_cap", strconv.Itoa(g.amdCap.defUW))
		}
		_ = writeSysfs(filepath.Join(dev, "power_dpm_force_performance_level"), "auto")
	}
}

// amdSetMaxSclk raises the sclk overdrive ceiling: OD needs manual mode, then a
// "s 1 <mhz>" edit committed with "c" (kernel pp_od_clk_voltage protocol).
func amdSetMaxSclk(dev, mhz string) error {
	if err := writeSysfs(filepath.Join(dev, "power_dpm_force_performance_level"), "manual"); err != nil {
		return err
	}
	od := filepath.Join(dev, "pp_od_clk_voltage")
	if err := writeSysfs(od, "s 1 "+mhz); err != nil {
		return err
	}
	return writeSysfs(od, "c")
}

// amdSetFan switches pwm1 to manual and writes the 0..255 duty for a 0..100 pct.
func amdSetFan(dev string, pct int) error {
	hw := firstHwmon(dev)
	if hw == "" {
		return fmt.Errorf("no hwmon fan on this GPU")
	}
	if err := writeSysfs(hw+"/pwm1_enable", "1"); err != nil { // 1 = manual
		return err
	}
	duty := clampInt(pct*255/100, 0, 255)
	return writeSysfs(hw+"/pwm1", strconv.Itoa(duty))
}

// ── small helpers ───────────────────────────────────────────────────────────

func parseOD(s string) *odRange {
	if s == "" {
		return nil
	}
	od := &odRange{}
	seen := false
	section := ""
	for _, line := range strings.Split(s, "\n") {
		line = strings.TrimSpace(line)
		switch {
		case strings.HasPrefix(line, "OD_SCLK"):
			section = "sclk"
		case strings.HasPrefix(line, "OD_RANGE"):
			section = "range"
		case section == "sclk" && strings.HasPrefix(line, "0:"):
			od.curMin = mhzOf(line)
		case section == "sclk" && strings.HasPrefix(line, "1:"):
			od.curMax = mhzOf(line)
		case section == "range" && strings.HasPrefix(line, "SCLK:"):
			f := strings.Fields(line)
			if len(f) >= 3 {
				od.minMHz = mhzWord(f[1])
				od.maxMHz = mhzWord(f[2])
				seen = true
			}
		}
	}
	if !seen {
		return nil
	}
	return od
}

// mhzOf pulls the MHz figure from "1:  2799Mhz" style lines.
func mhzOf(line string) int {
	f := strings.Fields(line)
	if len(f) < 2 {
		return 0
	}
	return mhzWord(f[1])
}

func mhzWord(w string) int {
	w = strings.TrimSpace(w)
	w = strings.TrimSuffix(strings.TrimSuffix(w, "Mhz"), "MHz")
	w = strings.TrimSuffix(w, "mhz")
	n, _ := strconv.Atoi(strings.TrimFunc(w, func(r rune) bool { return r < '0' || r > '9' }))
	return n
}

func firstHwmon(dev string) string {
	entries, err := os.ReadDir(filepath.Join(dev, "hwmon"))
	if err != nil {
		return ""
	}
	for _, e := range entries {
		if strings.HasPrefix(e.Name(), "hwmon") {
			return filepath.Join(dev, "hwmon", e.Name())
		}
	}
	return ""
}

func writeSysfs(path, content string) error {
	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
		return fmt.Errorf("write %s: %w", path, err)
	}
	return nil
}

func runErr(name string, args ...string) error {
	out, err := exec.Command(name, args...).CombinedOutput()
	if err != nil {
		return fmt.Errorf("%s: %v: %s", name, err, strings.TrimSpace(string(out)))
	}
	return nil
}

func readFile(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return string(b)
}

func readTrim(path string) string { return strings.TrimSpace(readFile(path)) }

func atoiTrim(s string) int { n, _ := strconv.Atoi(strings.TrimSpace(s)); return n }

func atofTrim(s string) float64 { f, _ := strconv.ParseFloat(strings.TrimSpace(s), 64); return f }

func clampf(v, lo, hi float64) float64 {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

func clampInt(v, lo, hi int) int {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}

func normalizePerf(s string) string {
	s = strings.TrimSpace(s)
	switch s {
	case "auto", "low", "high":
		return s
	default:
		return "auto" // manual/profile_* collapse to auto for the segment
	}
}

func boolStr(b bool) string {
	if b {
		return "on"
	}
	return "off"
}

func boolNum(v string) string {
	if v == "on" || v == "1" || v == "true" {
		return "1"
	}
	return "0"
}

// trimDot drops a trailing ".0" so "70.0" writes as "70" to tools that want ints.
func trimDot(v string) string {
	if i := strings.IndexByte(v, '.'); i >= 0 {
		return v[:i]
	}
	return v
}

func findTunable(ts []Tunable, gpu, id string) *Tunable {
	for i := range ts {
		if ts[i].GPU == gpu && ts[i].ID == id {
			return &ts[i]
		}
	}
	return nil
}

func findGPU(gs []gpuProbe, slot string) *gpuProbe {
	for i := range gs {
		if gs[i].slot == slot {
			return &gs[i]
		}
	}
	return nil
}

func inList(ss []string, s string) bool {
	for _, x := range ss {
		if x == s {
			return true
		}
	}
	return false
}

func orAll(s string) string {
	if s == "" {
		return "all"
	}
	return s
}
