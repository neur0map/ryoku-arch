// system.go holds everything that talks to the real machine: live lists for the
// pickers (keymaps, locales, time zones, disks, Wi-Fi), hardware detection, the
// small live actions (apply a keymap, hash a password, connect Wi-Fi), and the
// streamed handoff to the install backend. main.go stays pure UI; this file is the
// only place that shells out.
package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strconv"
	"strings"
	"sync"

	tea "charm.land/bubbletea/v2"
)

// run executes a command and returns its trimmed stdout, plus whether it worked.
// A missing tool or non-zero exit just yields ok=false so callers fall back.
func run(name string, args ...string) (string, bool) {
	out, err := exec.Command(name, args...).Output()
	if err != nil {
		return "", false
	}
	return strings.TrimSpace(string(out)), true
}

// promote reorders items so the preferred keys lead (nice defaults at the top of a
// long system list), keeping everything else in its original order.
func promote(items []item, prefer []string) []item {
	idx := map[string]int{}
	for i, k := range prefer {
		idx[k] = i
	}
	lead := make([]item, len(prefer))
	var rest []item
	var have []bool = make([]bool, len(prefer))
	for _, it := range items {
		if p, ok := idx[it.key]; ok {
			lead[p] = it
			have[p] = true
		} else {
			rest = append(rest, it)
		}
	}
	var out []item
	for i, it := range lead {
		if have[i] {
			out = append(out, it)
		}
	}
	return append(out, rest...)
}

// sysKeymaps lists console keymaps from localectl. WIRE target.
func sysKeymaps() []item {
	out, ok := run("localectl", "list-keymaps")
	if !ok {
		return nil
	}
	labels := map[string]string{
		"us": "US (QWERTY)", "uk": "United Kingdom", "gb": "United Kingdom",
		"de": "German", "fr": "French (AZERTY)", "es": "Spanish", "it": "Italian",
		"dvorak": "Dvorak", "colemak": "Colemak",
	}
	var items []item
	for _, l := range strings.Split(out, "\n") {
		c := strings.TrimSpace(l)
		if c == "" {
			continue
		}
		label := c
		if v, ok := labels[c]; ok {
			label = v
		}
		items = append(items, item{c, label, ""})
	}
	return promote(items, []string{"us", "uk", "gb", "de", "fr", "es", "it", "dvorak", "colemak"})
}

// sysLocales reads the supported UTF-8 locales (the ones we can generate).
func sysLocales() []item {
	var lines []string
	if data, err := os.ReadFile("/usr/share/i18n/SUPPORTED"); err == nil {
		for _, l := range strings.Split(string(data), "\n") {
			if strings.Contains(l, "UTF-8") {
				if f := strings.Fields(l); len(f) > 0 {
					lines = append(lines, f[0])
				}
			}
		}
	}
	if len(lines) == 0 {
		if out, ok := run("locale", "-a"); ok {
			for _, l := range strings.Split(out, "\n") {
				if strings.Contains(strings.ToLower(l), "utf") {
					lines = append(lines, strings.TrimSpace(l))
				}
			}
		}
	}
	var items []item
	for _, c := range lines {
		if c == "" {
			continue
		}
		items = append(items, item{c, c, ""})
	}
	return promote(items, []string{"en_US.UTF-8", "en_GB.UTF-8", "de_DE.UTF-8", "fr_FR.UTF-8", "es_ES.UTF-8"})
}

// sysTimezones lists time zones, with the auto-detect entry first.
func sysTimezones() []item {
	out, ok := run("timedatectl", "list-timezones")
	if !ok {
		return nil
	}
	items := []item{{"auto", "Detect automatically", "via IP, also sets the clock"}}
	for _, l := range strings.Split(out, "\n") {
		c := strings.TrimSpace(l)
		if c != "" {
			items = append(items, item{c, c, ""})
		}
	}
	return items
}

// lsblkPairs parses `lsblk -P` key="value" lines into maps.
func lsblkPairs(fields string) []map[string]string {
	out, ok := run("lsblk", "-dpno", fields, "-P")
	if !ok {
		return nil
	}
	var rows []map[string]string
	for _, line := range strings.Split(out, "\n") {
		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}
		m := map[string]string{}
		for _, tok := range splitPairs(line) {
			eq := strings.IndexByte(tok, '=')
			if eq < 0 {
				continue
			}
			k := tok[:eq]
			v := strings.Trim(tok[eq+1:], "\"")
			m[k] = v
		}
		rows = append(rows, m)
	}
	return rows
}

// splitPairs splits a lsblk -P line into KEY="value" tokens (values may hold spaces).
func splitPairs(line string) []string {
	var toks []string
	var b strings.Builder
	inQ := false
	for i := 0; i < len(line); i++ {
		c := line[i]
		if c == '"' {
			inQ = !inQ
			b.WriteByte(c)
		} else if c == ' ' && !inQ {
			if b.Len() > 0 {
				toks = append(toks, b.String())
				b.Reset()
			}
		} else {
			b.WriteByte(c)
		}
	}
	if b.Len() > 0 {
		toks = append(toks, b.String())
	}
	return toks
}

// sysDisks lists installable whole disks. WIRE target.
func sysDisks() []item {
	rows := lsblkPairs("NAME,SIZE,MODEL,TRAN,ROTA,TYPE")
	var items []item
	for _, r := range rows {
		if r["TYPE"] != "disk" {
			continue
		}
		name := r["NAME"]
		if strings.Contains(name, "zram") || strings.Contains(name, "/dev/sr") ||
			strings.Contains(name, "/dev/nbd") || strings.Contains(name, "loop") ||
			r["SIZE"] == "" || r["SIZE"] == "0B" {
			continue
		}
		kind := "SSD"
		if r["ROTA"] == "1" {
			kind = "HDD"
		}
		tran := strings.ToUpper(r["TRAN"])
		model := strings.TrimSpace(r["MODEL"])
		hint := strings.TrimSpace(fmt.Sprintf("%s · %s · %s %s", r["SIZE"], model, tran, kind))
		items = append(items, item{name, name, hint})
	}
	return items
}

// sysDiskSize returns a device size in GiB via blockdev. WIRE target.
func sysDiskSize(dev string) int {
	out, ok := run("blockdev", "--getsize64", dev)
	if !ok {
		return 0
	}
	n, err := strconv.ParseInt(strings.TrimSpace(out), 10, 64)
	if err != nil {
		return 0
	}
	return int(n / (1024 * 1024 * 1024))
}

// sysSSIDs lists the cached nearby Wi-Fi networks via nmcli. It uses --rescan no
// so it never blocks the UI on a scan; NetworkManager refreshes the cache on its
// own, and the picker's r key relists it. WIRE target.
func sysSSIDs() []item {
	out, ok := run("nmcli", "-t", "-f", "SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "no")
	if !ok {
		return nil
	}
	seen := map[string]bool{}
	var items []item
	for _, line := range strings.Split(out, "\n") {
		f := strings.Split(line, ":")
		if len(f) < 3 || f[0] == "" || seen[f[0]] {
			continue
		}
		seen[f[0]] = true
		sec := f[2]
		if sec == "" {
			sec = "open"
		}
		items = append(items, item{f[0], f[0], bars(f[1]) + " · " + sec})
	}
	return items
}

// bars renders a 0-100 signal value as a four-cell bar graph.
func bars(sig string) string {
	n, _ := strconv.Atoi(strings.TrimSpace(sig))
	full := n / 25
	if full > 4 {
		full = 4
	}
	return strings.Repeat("▆", full) + strings.Repeat("_", 4-full)
}

// hwInfo is the detected-hardware summary shown on the hardware card.
type hwInfo struct {
	cpu, gpu, mem, fw, disk, profile string
	hybrid, ok                       bool
}

var (
	hwCache hwInfo
	hwOnce  sync.Once
)

func ensureHW() hwInfo { hwOnce.Do(func() { hwCache = detectHardware() }); return hwCache }

// detectHardware probes CPU, GPU(s), memory, firmware, and disk, then suggests a
// profile and whether the machine is a hybrid iGPU+dGPU laptop. WIRE target.
func detectHardware() hwInfo {
	h := hwInfo{ok: true, profile: "vm"}

	if out, ok := run("lscpu"); ok {
		for _, l := range strings.Split(out, "\n") {
			if strings.HasPrefix(l, "Model name:") {
				h.cpu = strings.TrimSpace(strings.TrimPrefix(l, "Model name:"))
				break
			}
		}
	}

	virt, _ := run("systemd-detect-virt")
	isVM := virt != "" && virt != "none"

	gpuLines := []string{}
	hasNvidia, hasAMD, hasIntel := false, false, false
	if out, ok := run("sh", "-c", "lspci | grep -E 'VGA compatible controller|3D controller|Display controller'"); ok {
		for _, l := range strings.Split(out, "\n") {
			if strings.TrimSpace(l) == "" {
				continue
			}
			gpuLines = append(gpuLines, l)
			ll := strings.ToLower(l)
			switch {
			case strings.Contains(ll, "nvidia"):
				hasNvidia = true
			case strings.Contains(ll, "amd") || strings.Contains(ll, "ati") || strings.Contains(ll, "radeon"):
				hasAMD = true
			case strings.Contains(ll, "intel"):
				hasIntel = true
			}
		}
	}
	h.gpu = summarizeGPU(gpuLines)
	h.hybrid = hasNvidia && (hasAMD || hasIntel)

	if data, err := os.ReadFile("/proc/meminfo"); err == nil {
		for _, l := range strings.Split(string(data), "\n") {
			if strings.HasPrefix(l, "MemTotal:") {
				if f := strings.Fields(l); len(f) >= 2 {
					if kb, err := strconv.Atoi(f[1]); err == nil {
						h.mem = fmt.Sprintf("%d GiB", (kb+512*1024)/(1024*1024))
					}
				}
				break
			}
		}
	}

	if _, err := os.Stat("/sys/firmware/efi"); err == nil {
		h.fw = "UEFI"
	} else {
		h.fw = "BIOS"
	}
	if isVM {
		h.fw += " · virtual machine"
	} else {
		h.fw += " · bare metal"
	}

	if rows := lsblkPairs("NAME,SIZE,MODEL,ROTA,TYPE"); len(rows) > 0 {
		for _, r := range rows {
			if r["TYPE"] == "disk" && !strings.Contains(r["NAME"], "zram") && !strings.Contains(r["NAME"], "/dev/nbd") && !strings.Contains(r["NAME"], "loop") && r["SIZE"] != "" && r["SIZE"] != "0B" {
				kind := "SSD"
				if r["ROTA"] == "1" {
					kind = "HDD"
				}
				h.disk = strings.TrimSpace(fmt.Sprintf("%s · %s · %s (%s)", r["NAME"], r["SIZE"], r["MODEL"], kind))
				break
			}
		}
	}

	switch {
	case isVM:
		h.profile = "vm"
	case hasNvidia:
		h.profile = "amd-nvidia"
	case hasAMD:
		h.profile = "amd"
	case hasIntel:
		h.profile = "intel"
	default:
		h.profile = "vm"
		if len(gpuLines) == 0 {
			h.ok = false
		}
	}
	return h
}

func summarizeGPU(lines []string) string {
	var names []string
	for _, l := range lines {
		// Prefer the bracketed marketing name, e.g. "[GeForce RTX 4060]".
		if a := strings.LastIndex(l, "["); a >= 0 {
			if b := strings.Index(l[a:], "]"); b > 0 {
				names = append(names, strings.TrimSpace(l[a+1:a+b]))
				continue
			}
		}
		if i := strings.Index(l, ": "); i >= 0 {
			rest := l[i+2:]
			if j := strings.Index(rest, ": "); j >= 0 {
				rest = rest[j+2:]
			}
			names = append(names, strings.TrimSpace(rest))
		}
	}
	if len(names) == 0 {
		return "unclassified"
	}
	return strings.Join(names, " + ")
}

// applyKeymap loads the chosen console keymap so the rest of the wizard is typed
// in that layout. Best effort. WIRE target.
func applyKeymap(code string) { _ = exec.Command("loadkeys", code).Run() }

// applyExit runs the post-install action chosen on the done screen. reboot and
// poweroff hand off to systemd; anything else just returns so the live session
// ends and drops to a shell.
func applyExit(action string) {
	switch action {
	case "reboot":
		_ = exec.Command("systemctl", "reboot").Run()
	case "poweroff":
		_ = exec.Command("systemctl", "poweroff").Run()
	}
}

// autoTimezone resolves a time zone from the public IP. WIRE target.
func autoTimezone() string {
	if out, ok := run("curl", "-s", "--max-time", "3", "https://ipinfo.io/timezone"); ok {
		if tz := strings.TrimSpace(out); tz != "" {
			return tz
		}
	}
	return "UTC"
}

// hashPassword produces a sha512-crypt hash for useradd. WIRE target.
func hashPassword(pw string) string {
	cmd := exec.Command("openssl", "passwd", "-6", "-stdin")
	cmd.Stdin = strings.NewReader(pw + "\n")
	out, err := cmd.Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

// wifiConnect joins a network with nmcli. WIRE target.
func wifiConnect(ssid, pass string) bool {
	args := []string{"dev", "wifi", "connect", ssid}
	if pass != "" {
		args = append(args, "password", pass)
	}
	return exec.Command("nmcli", args...).Run() == nil
}

// ───────────────────────── install handoff ─────────────────────────

// installEnv builds the RYOKU_* environment the backend reads (install-contract.md).
func (m model) installEnv() []string {
	b := func(v bool) string {
		if v {
			return "1"
		}
		return "0"
	}
	env := []string{
		"RYOKU_DISK=" + m.diskDev,
		"RYOKU_DISK_STRATEGY=" + def(m.picks["disk"], "whole"),
		"RYOKU_HOSTNAME=" + def(m.picks["hostname"], "ryoku"),
		"RYOKU_USERNAME=" + def(m.picks["username"], "ryoku"),
		"RYOKU_PASSWORD_HASH=" + m.pwHash,
		"RYOKU_KEYMAP=" + def(m.picks["keyboard"], "us"),
		"RYOKU_LOCALE=" + def(m.picks["locale"], "en_US.UTF-8"),
		"RYOKU_TIMEZONE=" + def(m.picks["timezone"], "UTC"),
		"RYOKU_PROFILE=" + def(m.picks["profile"], "vm"),
		"RYOKU_ESP_GIB=" + strconv.Itoa(m.espG),
		"RYOKU_SWAP_GIB=" + strconv.Itoa(m.swapG),
		"RYOKU_SUBVOL_SNAPSHOTS=" + b(m.snapshots),
		"RYOKU_SUBVOL_HOME=" + b(m.sepHome),
		"RYOKU_SUBVOL_BACKUPS=" + b(m.backups),
	}
	if m.picks["gpu"] != "" {
		env = append(env, "RYOKU_GPU_MODE="+m.picks["gpu"])
	}
	if m.picks["encryption"] == "LUKS" {
		env = append(env, "RYOKU_ENCRYPT=1", "RYOKU_LUKS_PASSPHRASE="+m.luksPass)
	}
	return env
}

func def(v, fallback string) string {
	if strings.TrimSpace(v) == "" {
		return fallback
	}
	return v
}

// install messages flow from the backend goroutine into the Bubble Tea loop.
type installLineMsg string
type installStepMsg int
type installDoneMsg struct{ err error }

type installStream struct{ ch chan tea.Msg }

func (s *installStream) wait() tea.Cmd { return func() tea.Msg { return <-s.ch } }

// stepIndex maps a backend @@RYOKU_STEP id to an install row.
func stepIndex(id string) (int, bool) {
	order := []string{"partition", "filesystems", "mount", "pacstrap", "configure", "bootloader"}
	for i, s := range order {
		if s == id {
			return i, true
		}
	}
	return 0, false
}

// startInstall launches the backend with the built environment and streams its
// output as messages. The backend path comes from RYOKU_BACKEND or PATH.
func (m *model) startInstall() tea.Cmd {
	st := &installStream{ch: make(chan tea.Msg, 128)}
	m.istream = st
	env := append(os.Environ(), m.installEnv()...)
	bin := os.Getenv("RYOKU_BACKEND")
	if bin == "" {
		bin = "ryoku-install"
	}
	go func() {
		cmd := exec.Command(bin)
		cmd.Env = env
		pr, pw := io.Pipe()
		cmd.Stdout, cmd.Stderr = pw, pw
		if err := cmd.Start(); err != nil {
			st.ch <- installDoneMsg{err}
			return
		}
		done := make(chan error, 1)
		go func() { done <- cmd.Wait(); pw.Close() }()
		sc := bufio.NewScanner(pr)
		sc.Buffer(make([]byte, 1<<20), 1<<20)
		for sc.Scan() {
			line := sc.Text()
			if id, ok := strings.CutPrefix(line, "@@RYOKU_STEP "); ok {
				if idx, ok := stepIndex(strings.TrimSpace(id)); ok {
					st.ch <- installStepMsg(idx)
					continue
				}
			}
			if line == "@@RYOKU_DONE" {
				continue
			}
			st.ch <- installLineMsg(line)
		}
		st.ch <- installDoneMsg{<-done}
	}()
	return st.wait()
}

// netOnline reports whether the live system already has internet. WIRE target.
func netOnline() bool {
	if out, ok := run("ip", "-4", "route"); ok && strings.Contains(out, "default") {
		return true
	}
	return exec.Command("ping", "-c", "1", "-W", "1", "8.8.8.8").Run() == nil
}

// netInterface returns the active default-route interface name, for the
// connected screen (for example "eth0" or "enp1s0"). WIRE target.
func netInterface() string {
	if out, ok := run("sh", "-c", "ip -4 route show default | awk '{print $5; exit}'"); ok && out != "" {
		return out
	}
	return "online"
}
