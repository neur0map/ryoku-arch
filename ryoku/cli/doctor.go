package main

import (
	"bufio"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// ryoku doctor runs convergent reconcilers: idempotent checks (and, where it is
// safe, fixes) for stateful drift that `ryoku update` and `ryoku materialize`
// cannot express declaratively (disk layout, package channel, session pieces).
// Each reconciler reports "ok" when the machine already matches the desired
// state, otherwise it converges, proposes the exact fix, or flags it for a human.
// What it cannot fix it records: `ryoku doctor --report` writes a single shareable
// text file of findings plus system state for the maintainers.
//
// Reconcilers are safe to run on every update; retire one once every supported
// install has run it, so the set stays small instead of piling up like an ordered
// migration ledger.

const ryokuIssuesURL = "https://github.com/neur0map/ryoku-arch/issues"

type recStatus int

const (
	recOK recStatus = iota
	recFixed
	recWouldFix
	recWarn
	recFailed
)

func (s recStatus) label() string {
	switch s {
	case recOK:
		return "ok"
	case recFixed:
		return "fixed"
	case recWouldFix:
		return "todo"
	case recWarn:
		return "warn"
	case recFailed:
		return "fail"
	}
	return "?"
}

type recResult struct {
	status recStatus
	detail string
	remedy string // exact command or hint, shown for todo/warn/fail
}

func okRes(f string, a ...any) recResult {
	return recResult{status: recOK, detail: fmt.Sprintf(f, a...)}
}
func fixedRes(f string, a ...any) recResult {
	return recResult{status: recFixed, detail: fmt.Sprintf(f, a...)}
}
func wouldRes(f string, a ...any) recResult {
	return recResult{status: recWouldFix, detail: fmt.Sprintf(f, a...)}
}
func warnRes(f string, a ...any) recResult {
	return recResult{status: recWarn, detail: fmt.Sprintf(f, a...)}
}
func failRes(f string, a ...any) recResult {
	return recResult{status: recFailed, detail: fmt.Sprintf(f, a...)}
}

func (r recResult) withFix(f string, a ...any) recResult {
	r.remedy = fmt.Sprintf(f, a...)
	return r
}

type reconciler struct {
	name string
	run  func(checkOnly bool) recResult
}

func reconcilers() []reconciler {
	return []reconciler{
		{"swap kept out of snapshots", reconcileSwapSubvolume},
		{"snapper configuration", reconcileSnapper},
		{"pacman database lock", reconcilePacmanLock},
		{"ryoku package channel", reconcileRyokuChannel},
		{"desktop session components", reconcileSessionComponents},
		{"Hyprland config integrity", reconcileHyprlandConfig},
		{"ryoku shell daemon", reconcileShellDaemon},
		{"failed services", reconcileFailedUnits},
		{"btrfs device health", reconcileBtrfsHealth},
		{"display backlight", reconcileBacklight},
		{"pending config (.pacnew)", reconcilePacnew},
		{"orphaned packages", reconcileOrphans},
	}
}

type finding struct {
	name string
	res  recResult
}

func runReconcilers(checkOnly bool) []finding {
	out := make([]finding, 0, len(reconcilers()))
	for _, r := range reconcilers() {
		out = append(out, finding{r.name, r.run(checkOnly)})
	}
	return out
}

// printFindings prints one line per finding (plus its remedy). When not verbose
// it shows only the non-ok lines, matching the "a healthy machine is quiet"
// convention. It returns the warn and fail counts.
func printFindings(fs []finding, verbose bool) (warns, fails int) {
	width := termWidth()
	printed := 0
	for _, f := range fs {
		switch f.res.status {
		case recWarn:
			warns++
		case recFailed:
			fails++
		}
		if !verbose && f.res.status == recOK {
			continue
		}
		printed++
		w := os.Stdout
		if f.res.status == recWarn || f.res.status == recFailed {
			w = os.Stderr
		}
		fmt.Fprintf(w, "  %s %s\n", statusGlyph(f.res.status), statusName(f))
		if f.res.detail != "" {
			fmt.Fprintln(w, detailStyle(f.res.status, wrap(f.res.detail, width, "      ")))
		}
		if f.res.remedy != "" && f.res.status >= recWouldFix {
			fmt.Fprintln(w, brand(wrap("↳ "+f.res.remedy, width, "      ")))
		}
	}
	if printed == 0 {
		fmt.Println("  " + green("✓") + " all checks passed")
	}
	return warns, fails
}

func statusGlyph(s recStatus) string {
	switch s {
	case recOK, recFixed:
		return green("✓")
	case recWouldFix:
		return amber("›")
	case recWarn:
		return amber("!")
	case recFailed:
		return red("✗")
	}
	return " "
}

func statusName(f finding) string {
	if f.res.status == recOK {
		return f.name
	}
	name := bold(f.name)
	if f.res.status == recFixed {
		name += dim(" (fixed)")
	}
	return name
}

func detailStyle(s recStatus, text string) string {
	if s == recOK || s == recFixed {
		return dim(text)
	}
	return text
}

func doctorUsage() {
	fmt.Print(`Usage: ryoku doctor [--check] [--report [file]] [--explain]

  (no args)        check, and apply the safe automatic fixes
  --check, -n      report what is wrong without changing anything
  --report [file]  write a shareable diagnostic report for the maintainers
                   (default: ` + reportPath("") + `)
  --explain        ask your cloud model (Groq/OpenRouter) to reason over the report
`)
}

// cmdDoctor checks the machine, applies safe fixes, and on trouble it cannot fix
// writes a maintainer report so the user always has something to share.
func cmdDoctor(args []string) error {
	checkOnly, wantReport, wantExplain := false, false, false
	reportTo := ""
	for i := 0; i < len(args); i++ {
		switch a := args[i]; a {
		case "--check", "-n", "--dry-run":
			checkOnly = true
		case "--report":
			wantReport = true
			if i+1 < len(args) && !strings.HasPrefix(args[i+1], "-") {
				reportTo = args[i+1]
				i++
			}
		case "--explain":
			wantExplain = true
		case "-h", "--help":
			doctorUsage()
			return nil
		default:
			return fmt.Errorf("unknown argument: %s (try --help)", a)
		}
	}

	verbose := checkOnly || wantReport || wantExplain
	findings := runReconcilers(verbose) // report and check modes never mutate
	warns, fails := printFindings(findings, verbose)

	if wantExplain {
		return explainFindings(findings)
	}

	if wantReport {
		path, err := writeReport(reportTo, findings)
		if err != nil {
			return fmt.Errorf("writing report: %w", err)
		}
		fmt.Printf("\n  %s diagnostic report written to %s\n", brand("➜"), path)
		fmt.Println("    " + dim("share it with the maintainers: "+ryokuIssuesURL))
		return nil
	}

	// Could not fix everything: surface the AI option and a saved report so the
	// user always has a next step and a file to share.
	if warns+fails > 0 {
		path, _ := writeReport("", findings)
		noun := "issue"
		if warns+fails > 1 {
			noun = "issues"
		}
		fmt.Fprintf(os.Stderr, "\n  %s %s\n", brand("➜"), bold(fmt.Sprintf("found %d %s", warns+fails, noun)))
		fmt.Fprintf(os.Stderr, "    %s  %s\n", brand("ryoku doctor --explain"), dim("AI diagnosis and a suggested fix"))
		if path != "" {
			fmt.Fprintf(os.Stderr, "    %s\n", dim("report saved: "+path))
		}
	}
	if fails > 0 {
		return fmt.Errorf("%d check(s) failed", fails)
	}
	return nil
}

// ---- reconciler: swapfile out of snapshotted subvolumes ----------------------

// reconcileSwapSubvolume relocates a swapfile that lives inside @ (the
// snapshotted root) into its own btrfs subvolume. btrfs cannot snapshot a
// subvolume that holds an active swapfile, so the old installer layout made every
// snapper snapshot fail. Only the exact layout the old installer produced (a
// single swapfile in a plain directory on btrfs) is auto-fixed; anything else is
// reported for a human. It no-ops once the swapfile already sits in its own
// subvolume, and skips machines that do not snapshot root.
func reconcileSwapSubvolume(checkOnly bool) recResult {
	if !exists("/etc/snapper/configs/root") {
		return okRes("root snapshots not configured, nothing to keep out of them")
	}
	for _, sw := range activeSwapFiles() {
		dir := filepath.Dir(sw.path)
		if !isBtrfs(dir) || isBtrfsSubvolumeRoot(dir) {
			continue
		}
		if !dirOnlyContains(dir, filepath.Base(sw.path)) {
			return warnRes("swapfile %s blocks snapshots; %s holds other files", sw.path, dir).
				withFix("move the swapfile into its own subvolume by hand")
		}
		if checkOnly {
			return wouldRes("swapfile %s sits in snapshotted %s", sw.path, dir).
				withFix("ryoku doctor (moves it into its own btrfs subvolume)")
		}
		if err := relocateSwapToSubvolume(sw, dir); err != nil {
			return failRes("relocating %s: %v", sw.path, err)
		}
		return fixedRes("moved %s into its own btrfs subvolume so snapshots work", sw.path)
	}
	return okRes("swap is out of snapshots")
}

// ---- reconciler: snapper configuration consistency ---------------------------

func reconcileSnapper(_ bool) recResult {
	if !exists("/etc/snapper/configs/root") {
		return okRes("root snapshots not configured")
	}
	var problems []string
	if exists("/.snapshots") && !isBtrfsSubvolumeRoot("/.snapshots") {
		problems = append(problems, "/.snapshots is a plain directory, not a btrfs subvolume")
	}
	if fi, err := os.Stat("/.snapshots"); err == nil && fi.Mode().Perm() != 0o750 {
		problems = append(problems, fmt.Sprintf("/.snapshots is mode %04o, expected 0750", fi.Mode().Perm()))
	}
	if conf, err := os.ReadFile("/etc/conf.d/snapper"); err == nil && !strings.Contains(string(conf), "root") {
		problems = append(problems, "/etc/conf.d/snapper does not list the root config (timers and hooks will skip it)")
	}
	if len(problems) == 0 {
		return okRes("snapper root config is consistent")
	}
	return warnRes("%s", strings.Join(problems, "; ")).
		withFix("see https://wiki.archlinux.org/title/Snapper")
}

// ---- reconciler: stale pacman lock -------------------------------------------

func reconcilePacmanLock(checkOnly bool) recResult {
	const lock = "/var/lib/pacman/db.lck"
	if !exists(lock) {
		return okRes("no stale pacman lock")
	}
	if processRunning("pacman") {
		return okRes("pacman is running; lock is in use")
	}
	if checkOnly {
		return wouldRes("stale pacman lock present (no pacman running)").withFix("sudo rm %s", lock)
	}
	if err := run("sudo", "rm", "-f", lock); err != nil {
		return failRes("could not remove stale lock: %v", err).withFix("sudo rm %s", lock)
	}
	return fixedRes("removed stale pacman lock")
}

// ---- reconciler: ryoku package channel + keyring -----------------------------

func reconcileRyokuChannel(_ bool) recResult {
	if !pkgInstalled("ryoku-desktop") {
		return okRes("not a packaged install (desktop runs from a checkout)")
	}
	conf, _ := os.ReadFile("/etc/pacman.conf")
	if !strings.Contains(string(conf), "[ryoku]") {
		return warnRes("ryoku-desktop is installed but the [ryoku] repo is not in pacman.conf; updates will not arrive").
			withFix("add the [ryoku] repo (see docs/development.md)")
	}
	if !pkgInstalled("ryoku-keyring") {
		return warnRes("the [ryoku] repo is configured but ryoku-keyring is missing; signatures will fail").
			withFix("sudo pacman -S ryoku-keyring")
	}
	return okRes("ryoku package channel configured")
}

// ---- reconciler: desktop session components ----------------------------------

func reconcileSessionComponents(_ bool) recResult {
	if !exists(filepath.Join(homeDir(), ".config", "hypr")) && !has("Hyprland") {
		return okRes("not a Hyprland desktop")
	}
	checks := []struct {
		role, fix string
		any       []string
	}{
		{"authentication agent", "sudo pacman -S hyprpolkitagent", []string{"hyprpolkitagent", "polkit-gnome", "polkit-kde-agent", "lxsession"}},
		{"desktop portal", "sudo pacman -S xdg-desktop-portal-hyprland", []string{"xdg-desktop-portal-hyprland"}},
		{"audio server", "sudo pacman -S pipewire wireplumber", []string{"pipewire"}},
		{"network manager", "sudo pacman -S networkmanager", []string{"networkmanager"}},
	}
	var missing []string
	for _, c := range checks {
		if !anyPkgInstalled(c.any...) {
			missing = append(missing, fmt.Sprintf("%s [%s]", c.role, c.fix))
		}
	}
	if len(missing) == 0 {
		return okRes("desktop session components present")
	}
	return warnRes("missing: %s", strings.Join(missing, "; "))
}

// ---- reconciler: ryoku shell daemon ------------------------------------------

// reconcileShellDaemon checks the Ryoku shell control plane is alive. The daemon
// (`ryoku-shell daemon`, autostarted by Hyprland) owns the Unix socket every
// keybind and quickshell component talks to; if it dies the whole shell is dead
// while the session target still looks up. Hyprland starts it once at login, so a
// crash leaves nothing to bring it back -- which is what doctor is for. Inside a
// live session it restarts the daemon; from a TTY or ssh there is no shell to
// manage, so it stays quiet.
func reconcileShellDaemon(checkOnly bool) recResult {
	if os.Getenv("HYPRLAND_INSTANCE_SIGNATURE") == "" {
		return okRes("not in a live Hyprland session")
	}
	if !has("ryoku-shell") {
		return warnRes("ryoku-shell is not installed; the desktop shell cannot run").
			withFix("redeploy the shell: `ryoku update` (or ryoku/shell/deploy.sh from a checkout)")
	}
	if shellDaemonReachable() {
		return okRes("shell daemon reachable")
	}
	if checkOnly {
		return wouldRes("shell daemon is down; the shell, keybinds and panels are dead").
			withFix("start it with `ryoku-shell daemon` (Hyprland autostarts it at login)")
	}
	if err := startShellDaemon(); err != nil {
		return failRes("shell daemon is down and could not be started: %v", err).
			withFix("start it in a terminal to see why: `ryoku-shell daemon`")
	}
	if waitDaemonReachable(5 * time.Second) {
		return fixedRes("shell daemon was down; restarted it")
	}
	return failRes("started ryoku-shell daemon but it did not come up").
		withFix("run `ryoku-shell daemon` in a terminal to see why it exits")
}

// shellDaemonReachable dials the shell control socket and pings it, the same
// round-trip the keybinds make. A stale socket from a crashed daemon refuses the
// connection; a hung daemon accepts but never replies, so the read is bounded.
func shellDaemonReachable() bool {
	dir := os.Getenv("XDG_RUNTIME_DIR")
	if dir == "" {
		dir = "/tmp"
	}
	conn, err := net.DialTimeout("unix", filepath.Join(dir, "ryoku-shell.sock"), time.Second)
	if err != nil {
		return false
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(2 * time.Second))
	if _, err := fmt.Fprintln(conn, "ping"); err != nil {
		return false
	}
	buf := make([]byte, 64)
	n, _ := conn.Read(buf)
	return strings.TrimSpace(string(buf[:n])) == "ok"
}

// startShellDaemon launches `ryoku-shell daemon` detached from doctor: its own
// session so it outlives this process, stdio to /dev/null. The daemon removes a
// stale socket and refuses to double-start, so this is safe to call only when the
// socket is already unreachable.
func startShellDaemon() error {
	cmd := exec.Command("ryoku-shell", "daemon")
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if devnull, err := os.OpenFile(os.DevNull, os.O_RDWR, 0); err == nil {
		cmd.Stdin, cmd.Stdout, cmd.Stderr = devnull, devnull, devnull
		defer devnull.Close()
	}
	return cmd.Start()
}

// waitDaemonReachable polls until the daemon answers or the deadline passes; the
// daemon needs a moment to bind the socket and bootstrap.
func waitDaemonReachable(d time.Duration) bool {
	deadline := time.Now().Add(d)
	for {
		if shellDaemonReachable() {
			return true
		}
		if time.Now().After(deadline) {
			return false
		}
		time.Sleep(150 * time.Millisecond)
	}
}

// ---- reconciler: Hyprland config integrity -----------------------------------

// hyprDropin is a runtime-generated Hyprland Lua drop-in. hyprland.lua loads
// monitors.lua (ryoku-monitor) and gpu.lua (ryoku-gpu); both are rewritten while
// the session runs (a display hotplug or a GPU reset re-runs the generators), so
// a crash or a truncated write can leave one unparseable. If Hyprland then
// reloads, it rejects the whole config and drops into its on-screen emergency
// mode -- the "reload/doctor/update do nothing, only a reboot fixes it" failure --
// until the file is repaired.
type hyprDropin struct {
	name     string   // file under ~/.config/hypr
	regen    []string // generator that rewrites it from live state
	needLive bool     // generator needs a running compositor
	seed     string   // known-good fallback: always parseable, safe default
}

func hyprDropins() []hyprDropin {
	return []hyprDropin{
		{
			name:     "monitors.lua",
			regen:    []string{"ryoku-monitor", "persist"},
			needLive: true,
			seed: "-- Reset by ryoku doctor after a corrupt write. Brings every output up at a\n" +
				"-- safe 1x; `ryoku-monitor autoscale` (runs at the next login) restores scaling.\n" +
				"hl.monitor({ output = \"\", mode = \"highrr\", position = \"auto\", scale = 1 })\n",
		},
		{
			name:     "gpu.lua",
			regen:    []string{"ryoku-gpu", "persist"},
			needLive: false,
			seed: "-- Reset by ryoku doctor after a corrupt write. Hyprland picks its own GPU;\n" +
				"-- run `ryoku-gpu persist` to re-pin the primary on a multi-GPU machine.\n",
		},
	}
}

// reconcileHyprlandConfig keeps the Hyprland config loadable, the generic cure for
// the "desktop dropped into emergency mode and only a reboot helped" report. It
// validates that the runtime-generated drop-ins still parse (a crash-truncated one
// would wedge the next reload) and, in a live session, asks Hyprland whether it is
// currently rejecting its config. A corrupt drop-in is regenerated from live state
// or reset to a safe seed; in a live session the config is then reloaded so the
// desktop leaves emergency mode at once instead of needing a reboot. It is
// hardware-agnostic: it only ever validates and repairs config files.
func reconcileHyprlandConfig(checkOnly bool) recResult {
	dir := filepath.Join(configHome(), "hypr")
	if !exists(filepath.Join(dir, "hyprland.lua")) {
		return okRes("no Hyprland config present")
	}
	live := hyprLive()

	if checkOnly {
		var broken []string
		for _, d := range hyprDropins() {
			p := filepath.Join(dir, d.name)
			if exists(p) && !hyprLuaParseable(p) {
				broken = append(broken, d.name)
			}
		}
		if len(broken) > 0 {
			return wouldRes("corrupt Hyprland drop-in(s) would wedge the next reload into emergency mode: %s", strings.Join(broken, ", ")).
				withFix("run `ryoku doctor` to regenerate them")
		}
		if e := liveConfigErrors(live); e != "" {
			return wouldRes("Hyprland is rejecting its config (emergency mode): %s", firstLine(e)).
				withFix("run `ryoku doctor`, then check ~/.config/hypr/user.lua")
		}
		return okRes("Hyprland config loads cleanly")
	}

	var repaired, failed []string
	for _, d := range hyprDropins() {
		p := filepath.Join(dir, d.name)
		if !exists(p) || hyprLuaParseable(p) {
			continue
		}
		if repairHyprDropin(dir, d, live) {
			repaired = append(repaired, d.name)
		} else {
			failed = append(failed, d.name)
		}
	}

	// A clean reload pulls a live session out of emergency mode immediately.
	if live && len(repaired) > 0 {
		_ = exec.Command("hyprctl", "reload").Run()
	}

	switch {
	case len(failed) > 0:
		return failRes("could not repair Hyprland drop-in(s): %s", strings.Join(failed, ", ")).
			withFix("inspect ~/.config/hypr/%s by hand", failed[0])
	case len(repaired) > 0:
		return fixedRes("regenerated corrupt Hyprland drop-in(s): %s; the config loads cleanly again", strings.Join(repaired, ", "))
	}

	if e := liveConfigErrors(live); e != "" {
		return warnRes("Hyprland is rejecting its config: %s", firstLine(e)).
			withFix("check ~/.config/hypr/user.lua, settings.lua, or theme.lua")
	}
	return okRes("Hyprland config loads cleanly")
}

// repairHyprDropin rewrites a corrupt drop-in: regenerate it from the live machine
// when its generator is available, else fall back to the safe seed. Both outcomes
// are re-validated, so even a generator that wrote garbage ends at a parseable file.
func repairHyprDropin(dir string, d hyprDropin, live bool) bool {
	p := filepath.Join(dir, d.name)
	if len(d.regen) > 0 && has(d.regen[0]) && (!d.needLive || live) {
		if exec.Command(d.regen[0], d.regen[1:]...).Run() == nil && hyprLuaParseable(p) {
			return true
		}
	}
	if os.WriteFile(p, []byte(d.seed), 0o644) != nil {
		return false
	}
	return hyprLuaParseable(p)
}

// hyprLuaParseable reports whether a Lua drop-in will load. luac -p is definitive
// (the lua toolchain ships with Hyprland's config stack); without it, fall back to
// catching the truncation failure mode -- an empty file or unbalanced brackets,
// which a whole generated drop-in (no brackets inside its string literals) never
// has. An unreadable file is left alone rather than clobbered.
func hyprLuaParseable(path string) bool {
	if has("luac") {
		return exec.Command("luac", "-p", path).Run() == nil
	}
	b, err := os.ReadFile(path)
	if err != nil {
		return true
	}
	return hyprLuaSane(string(b))
}

func hyprLuaSane(s string) bool {
	if strings.TrimSpace(s) == "" {
		return false
	}
	return balancedRunes(s, '(', ')') && balancedRunes(s, '{', '}')
}

func balancedRunes(s string, open, shut rune) bool {
	depth := 0
	for _, r := range s {
		switch r {
		case open:
			depth++
		case shut:
			depth--
			if depth < 0 {
				return false
			}
		}
	}
	return depth == 0
}

// liveConfigErrors returns Hyprland's current config errors (its emergency-mode
// reason), or "" when the config is clean or no live session is reachable.
func liveConfigErrors(live bool) string {
	if !live {
		return ""
	}
	out := strings.TrimSpace(captureOut("hyprctl", "configerrors"))
	if out == "" || (strings.HasPrefix(out, "(") && strings.HasSuffix(out, ")")) {
		return ""
	}
	return out
}

// ---- reconciler: failed systemd units ----------------------------------------

func reconcileFailedUnits(_ bool) recResult {
	var failed []string
	sys, _ := runOut("systemctl", "--failed", "--no-legend", "--plain")
	for _, l := range nonEmptyLines(sys) {
		if f := strings.Fields(l); len(f) > 0 {
			failed = append(failed, f[0])
		}
	}
	usr, _ := runOut("systemctl", "--user", "--failed", "--no-legend", "--plain")
	for _, l := range nonEmptyLines(usr) {
		if f := strings.Fields(l); len(f) > 0 {
			failed = append(failed, f[0]+" (user)")
		}
	}
	if len(failed) == 0 {
		return okRes("no failed services")
	}
	return warnRes("failed: %s", strings.Join(failed, ", ")).
		withFix("inspect with `systemctl status <unit>` and `journalctl -u <unit>`")
}

// ---- reconciler: btrfs device health -----------------------------------------

func reconcileBtrfsHealth(_ bool) recResult {
	if !isBtrfs("/") {
		return okRes("root is not btrfs")
	}
	opts, _ := runOut("findmnt", "-n", "-o", "OPTIONS", "/")
	if first := strings.SplitN(strings.TrimSpace(opts), ",", 2); len(first) > 0 && first[0] == "ro" {
		return warnRes("root filesystem is mounted read-only (btrfs may be protecting itself)").
			withFix("check `btrfs filesystem usage /`; may need `btrfs balance` or more free space")
	}
	stats, err := runOut("sudo", "-n", "btrfs", "device", "stats", "/")
	if err != nil || strings.TrimSpace(stats) == "" {
		return okRes("btrfs ok (device error counters need root for full detail)")
	}
	for _, l := range nonEmptyLines(stats) {
		f := strings.Fields(l)
		if len(f) == 2 && f[1] != "0" {
			return warnRes("btrfs reports device errors: %s", strings.TrimSpace(l)).
				withFix("back up, then `sudo btrfs scrub start /`; a non-zero counter can mean a failing disk")
		}
	}
	return okRes("btrfs device error counters clean")
}

// ---- reconciler: pending .pacnew config --------------------------------------

func reconcilePacnew(_ bool) recResult {
	out, _ := runOut("find", "/etc", "-name", "*.pacnew")
	files := nonEmptyLines(out)
	if len(files) == 0 {
		return okRes("no pending config updates")
	}
	return warnRes("%d pending config update(s) (.pacnew)", len(files)).
		withFix("review and merge with `sudo pacdiff` (from pacman-contrib)")
}

// ---- reconciler: orphaned packages -------------------------------------------

func reconcileOrphans(_ bool) recResult {
	out, err := runOut("pacman", "-Qtdq")
	orphans := nonEmptyLines(out)
	if err != nil || len(orphans) == 0 {
		return okRes("no orphaned packages")
	}
	return warnRes("%d orphaned package(s)", len(orphans)).
		withFix("review `pacman -Qtd`, then `sudo pacman -Rns $(pacman -Qtdq)` if unneeded")
}

// ---- diagnostic report -------------------------------------------------------

func reportPath(override string) string {
	if override != "" {
		return override
	}
	return filepath.Join(xdg("XDG_STATE_HOME", ".local/state"), "ryoku", "doctor-report.txt")
}

func writeReport(override string, findings []finding) (string, error) {
	path := reportPath(override)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return "", err
	}
	if err := os.WriteFile(path, []byte(gatherReport(findings)), 0o644); err != nil {
		return "", err
	}
	return path, nil
}

// gatherReport builds a single self-contained text report: the doctor findings
// followed by the system state a maintainer needs to diagnose the unknown. It is
// safe to share, it contains system state and recent error logs, no secrets.
func gatherReport(findings []finding) string {
	var b strings.Builder
	line := func(f string, a ...any) { fmt.Fprintf(&b, f+"\n", a...) }
	section := func(title string) { line("\n## %s", title) }
	cmd := func(name string, args ...string) {
		line("$ %s %s", name, strings.Join(args, " "))
		line("%s", captureOut(name, args...))
	}

	line("Ryoku diagnostic report")
	line("generated: %s", time.Now().Format(time.RFC3339))
	line("Safe to share with the Ryoku maintainers: system state and recent error")
	line("logs only, no passwords or keys. Open an issue: %s", ryokuIssuesURL)
	line(strings.Repeat("=", 70))

	section("doctor findings")
	for _, f := range findings {
		line("  %-5s %s: %s", f.res.status.label(), f.name, f.res.detail)
		if f.res.remedy != "" {
			line("        fix: %s", f.res.remedy)
		}
	}

	section("system")
	cmd("uname", "-srvmo")
	line("os-release:\n%s", readFileSafe("/etc/os-release"))

	section("ryoku")
	cmd("ryoku", "status")
	line("state dir:\n%s", captureOut("ls", "-la", filepath.Join(xdg("XDG_STATE_HOME", ".local/state"), "ryoku")))
	line("[ryoku] repo configured: %v", strings.Contains(readFileSafe("/etc/pacman.conf"), "[ryoku]"))

	section("storage (btrfs)")
	cmd("sudo", "-n", "btrfs", "filesystem", "usage", "/")
	cmd("sudo", "-n", "btrfs", "device", "stats", "/")
	line("/proc/swaps:\n%s", readFileSafe("/proc/swaps"))
	line("/etc/conf.d/snapper:\n%s", readFileSafe("/etc/conf.d/snapper"))

	section("packages")
	cmd("pacman", "-Qtdq")
	cmd("pacman", "-Dk")
	line(".pacnew files:\n%s", captureOut("find", "/etc", "-name", "*.pacnew"))
	line("pacman.log (tail):\n%s", tailLines(readFileSafe("/var/log/pacman.log"), 25))

	section("services")
	cmd("systemctl", "--failed", "--no-legend", "--plain")
	cmd("systemctl", "--user", "--failed", "--no-legend", "--plain")
	line("journal errors this boot (tail):\n%s", tailLines(captureOut("journalctl", "-b", "-p", "err", "--no-pager"), 40))

	section("desktop")
	cmd("ryoku-shell", "status")
	cmd("pgrep", "-af", "quickshell")
	for _, v := range []string{"WAYLAND_DISPLAY", "XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE", "HYPRLAND_INSTANCE_SIGNATURE"} {
		line("%s=%s", v, os.Getenv(v))
	}

	section("hardware")
	bl := backlightDevices()
	if len(bl) == 0 {
		line("backlight: (none found)")
	}
	for _, d := range bl {
		base := "/sys/class/backlight/" + d
		line("backlight %s: type=%s max=%s cur=%s actual=%s", d,
			readFileSafe(base+"/type"), readFileSafe(base+"/max_brightness"),
			readFileSafe(base+"/brightness"), readFileSafe(base+"/actual_brightness"))
	}
	line("gpu drivers loaded: %s", strings.Join(gpuDriversLoaded(), ", "))
	cmd("sh", "-c", "lspci -k 2>/dev/null | grep -iA3 'vga\\|3d controller' || true")
	line("kernel cmdline: %s", readFileSafe("/proc/cmdline"))
	line("kernel display log (tail):\n%s", captureOut("sh", "-c", "journalctl -k -b --no-pager 2>/dev/null | grep -iE 'backlight|amdgpu|nvidia|i915|drm' | tail -30 || true"))

	section("gpu / compositor stability")
	// Vendor-agnostic GPU-hang signatures: amdgpu (reset/wedged/VRAM lost/ring),
	// nvidia (NVRM Xid), i915 (GPU HANG). Bare "Xid" is avoided so an r8169 NIC's
	// "XID" line is not mistaken for a GPU fault. Search across boots (a crash
	// needs a reboot, so the evidence is in the previous boot, not the current one).
	const gpuHang = `GPU reset begin|device wedged|VRAM is lost|ring .* reset failed|NVRM: Xid|GPU HANG`
	line("GPU resets/hangs (last 14 days): %s", captureOut("sh", "-c",
		"journalctl --no-pager --since '-14 days' -g '"+gpuHang+"' 2>/dev/null | grep -cE '"+gpuHang+"'"))
	line("recent GPU reset/hang lines:\n%s", tailLines(captureOut("sh", "-c",
		"journalctl --no-pager --since '-14 days' -g '"+gpuHang+"' 2>/dev/null || true"), 12))
	line("compositor/session coredumps:\n%s", captureOut("sh", "-c",
		"coredumpctl list --no-pager 2>/dev/null | grep -iE 'Hyprland|Xwayland|quickshell|aquamarine' | tail -10 || true"))

	return b.String()
}

// ---- swap helpers ------------------------------------------------------------

type swapFile struct {
	path   string
	sizeKB int64
}

func activeSwapFiles() []swapFile {
	b, err := os.ReadFile("/proc/swaps")
	if err != nil {
		return nil
	}
	return parseProcSwaps(string(b))
}

// parseProcSwaps returns the file-backed swaps from /proc/swaps content. The
// first line is a header; the path field escapes spaces as \040.
func parseProcSwaps(s string) []swapFile {
	var out []swapFile
	sc := bufio.NewScanner(strings.NewReader(s))
	for i := 0; sc.Scan(); i++ {
		if i == 0 {
			continue
		}
		f := strings.Fields(sc.Text())
		if len(f) < 3 || f[1] != "file" {
			continue
		}
		size, err := strconv.ParseInt(f[2], 10, 64)
		if err != nil {
			continue
		}
		out = append(out, swapFile{path: strings.ReplaceAll(f[0], `\040`, " "), sizeKB: size})
	}
	return out
}

func isBtrfs(path string) bool {
	var st syscall.Statfs_t
	if err := syscall.Statfs(path, &st); err != nil {
		return false
	}
	return int64(st.Type) == 0x9123683E // BTRFS_SUPER_MAGIC
}

// isBtrfsSubvolumeRoot reports whether path is the root of a btrfs subvolume;
// those always carry inode 256.
func isBtrfsSubvolumeRoot(path string) bool {
	var st syscall.Stat_t
	if err := syscall.Stat(path, &st); err != nil {
		return false
	}
	return st.Ino == 256
}

func dirOnlyContains(dir, name string) bool {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return false
	}
	return len(entries) == 1 && entries[0].Name() == name
}

// relocateSwapToSubvolume swaps off the file, turns its directory into a btrfs
// subvolume, recreates the swapfile inside it at the same path and size, and
// swaps it back on. The path is unchanged, so the fstab swap entry still resolves
// and the nested subvolume appears with its parent: no fstab edit is needed.
func relocateSwapToSubvolume(sw swapFile, dir string) error {
	steps := [][]string{
		{"swapoff", sw.path},
		{"rm", "-f", sw.path},
		{"rmdir", dir},
		{"btrfs", "subvolume", "create", dir},
		{"btrfs", "filesystem", "mkswapfile", "--size", fmt.Sprintf("%dk", sw.sizeKB), sw.path},
		{"swapon", sw.path},
	}
	for _, s := range steps {
		if err := run("sudo", s...); err != nil {
			return fmt.Errorf("%s: %w", strings.Join(s, " "), err)
		}
	}
	return nil
}

// ---- small shared helpers ----------------------------------------------------

func homeDir() string {
	if h, err := os.UserHomeDir(); err == nil {
		return h
	}
	return os.Getenv("HOME")
}

func firstLine(s string) string {
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		return strings.TrimSpace(s[:i])
	}
	return strings.TrimSpace(s)
}

func pkgInstalled(name string) bool {
	return exec.Command("pacman", "-Q", name).Run() == nil
}

func anyPkgInstalled(names ...string) bool {
	for _, n := range names {
		if pkgInstalled(n) {
			return true
		}
	}
	return false
}

func processRunning(name string) bool {
	return exec.Command("pgrep", "-x", name).Run() == nil
}

func nonEmptyLines(s string) []string {
	var out []string
	for _, l := range strings.Split(s, "\n") {
		if strings.TrimSpace(l) != "" {
			out = append(out, l)
		}
	}
	return out
}

// captureOut runs a command and returns its combined output (or the error text),
// for best-effort diagnostics where a non-zero exit is still informative.
func captureOut(name string, args ...string) string {
	out, err := exec.Command(name, args...).CombinedOutput()
	s := strings.TrimRight(string(out), "\n")
	if s == "" && err != nil {
		return "(" + err.Error() + ")"
	}
	if s == "" {
		return "(none)"
	}
	return s
}

func readFileSafe(path string) string {
	b, err := os.ReadFile(path)
	if err != nil {
		return "(" + err.Error() + ")"
	}
	return strings.TrimRight(string(b), "\n")
}

func tailLines(s string, n int) string {
	lines := strings.Split(strings.TrimRight(s, "\n"), "\n")
	if len(lines) > n {
		lines = lines[len(lines)-n:]
	}
	return strings.Join(lines, "\n")
}

// ---- reconciler: display backlight -------------------------------------------

// reconcileBacklight flags the common display-brightness failures: no backlight
// interface at all, a backlight present but no brightnessctl to drive it, and the
// hybrid-GPU laptop case where the only interface is a firmware backlight. For the
// last it reads the kernel's own verdict (the dGPU reporting no native backlight)
// rather than trusting a sysfs value the panel may ignore. Detect-and-warn only:
// the fixes (a GPU mux switch, kernel parameters) are too machine-specific to
// apply blindly.
func reconcileBacklight(_ bool) recResult {
	devs := backlightDevices()
	if len(devs) == 0 {
		if !isLaptop() {
			return okRes("no internal backlight (desktop or external display)")
		}
		return warnRes("no backlight interface found; display brightness cannot be set").
			withFix("try a kernel parameter such as acpi_backlight=native or acpi_backlight=vendor")
	}
	if !has("brightnessctl") {
		return warnRes("backlight present but brightnessctl is missing; brightness keys and idle-dim will not work").
			withFix("sudo pacman -S brightnessctl")
	}
	if gpus := gpuDriversLoaded(); len(gpus) >= 2 && onlyFirmwareBacklight(devs) {
		detail := fmt.Sprintf("hybrid GPU (%s) with only a firmware backlight (%s); the panel may not dim",
			strings.Join(gpus, "+"), strings.Join(devs, ","))
		if nvidiaBacklightDead() {
			detail = fmt.Sprintf("hybrid GPU (%s): the kernel reports the dGPU has no working backlight, and the firmware fallback (%s) does not dim the panel",
				strings.Join(gpus, "+"), strings.Join(devs, ","))
		}
		fix := "route the panel to the iGPU: set the BIOS GPU/MUX mode to Hybrid and reboot, then amdgpu_bl0 appears"
		if has("supergfxctl") {
			fix += "; on a supported ASUS laptop `supergfxctl -m Hybrid` switches it without a BIOS trip"
		}
		return warnRes("%s", detail).withFix(fix)
	}
	return okRes("backlight: %s", strings.Join(devs, ", "))
}

// nvidiaBacklightDead reports the kernel's own tell that the dGPU has no usable
// backlight and fell back to the frequently non-functional ACPI/EC interface.
func nvidiaBacklightDead() bool {
	n := strings.TrimSpace(captureOut("sh", "-c",
		"journalctl -k -b --no-pager 2>/dev/null | grep -ic 'no NVIDIA native backlight'"))
	return n != "" && n != "0"
}

func backlightDevices() []string {
	entries, err := os.ReadDir("/sys/class/backlight")
	if err != nil {
		return nil
	}
	out := make([]string, 0, len(entries))
	for _, e := range entries {
		out = append(out, e.Name())
	}
	return out
}

func onlyFirmwareBacklight(devs []string) bool {
	for _, d := range devs {
		if strings.TrimSpace(readFileSafe("/sys/class/backlight/"+d+"/type")) != "firmware" {
			return false
		}
	}
	return len(devs) > 0
}

// gpuDriversLoaded returns the loaded GPU kernel drivers, so a hybrid-GPU machine
// is recognizable.
func gpuDriversLoaded() []string {
	var out []string
	for _, m := range []string{"amdgpu", "nvidia", "i915", "nouveau", "xe"} {
		if exists("/sys/module/" + m) {
			out = append(out, m)
		}
	}
	return out
}

// isLaptop reports whether the machine has a battery, i.e. an internal panel
// whose backlight we would expect to control.
func isLaptop() bool {
	entries, err := os.ReadDir("/sys/class/power_supply")
	if err != nil {
		return false
	}
	for _, e := range entries {
		if strings.HasPrefix(e.Name(), "BAT") {
			return true
		}
	}
	return false
}
