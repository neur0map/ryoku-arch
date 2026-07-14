package doctor

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"ryoku-cli/internal/sys"
	"strconv"
	"strings"
	"syscall"
	"time"
)

// doctor = the convergent reconcilers. idempotent checks (plus a fix where
// it's safe) for the stateful drift that `ryoku update` / `ryoku materialize`
// can't say declaratively: disk layout, package channel, session bits. each
// one returns "ok" if the box already matches, else converges, prints the
// exact fix, or punts to a human.
//
// whatever can't be fixed gets written down: `ryoku doctor --report` dumps the
// findings + system state to one shareable text file for the maintainers.
//
// reconcilers are safe on every update. retire one once every supported install
// has run it, so the set stays small instead of piling up like a migration
// ledger.

const ryokuIssuesURL = "https://github.com/neur0map/ryoku-arch/issues"

type recStatus int

const (
	recOK recStatus = iota
	recNote
	recFixed
	recWouldFix
	recWarn
	recFailed
)

func (s recStatus) label() string {
	switch s {
	case recOK:
		return "ok"
	case recNote:
		return "note"
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
func noteRes(f string, a ...any) recResult {
	return recResult{status: recNote, detail: fmt.Sprintf(f, a...)}
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
		{"limine boot menu layout", reconcileLimineLayout},
		{"limine boot entry", reconcileLimineBootEntry},
		{"limine UKI boot tree", reconcileLimineUKITree},
		{"limine snapshot sync", reconcileLimineOSName},
		{"pacman database lock", reconcilePacmanLock},
		{"stale update run-state", reconcileStaleUpdateRun},
		{"stale install crypt mapper", reconcileStaleCryptMapper},
		{"ryoku package channel", reconcileRyokuChannel},
		{"stale dev residue", reconcileDevResidue},
		{"desktop session components", reconcileSessionComponents},
		{"desktop portal routing", reconcilePortalRouting},
		{"cursor theme", reconcileCursorTheme},
		{"Material Symbols icon font", reconcileIconFont},
		{"wallpaper daemons", reconcileWallpaperDaemon},
		{"shell config schema", reconcileShellConfig},
		{"SDDM greeter theme", reconcileGreeterTheme},
		{"fastfetch readout emblem", reconcileFastfetchEmblem},
		{"brand mark image", reconcileBrandLogo},
		{"Hyprland config integrity", reconcileHyprlandConfig},
		{"orphaned theme.lua", reconcileThemeLua},
		{"follow-mouse default", reconcileFollowMouseDefault},
		{"ryoku shell daemon", reconcileShellDaemon},
		{"failed services", reconcileFailedUnits},
		{"btrfs device health", reconcileBtrfsHealth},
		{"display backlight", reconcileBacklight},
		{"display resolution", reconcileDisplayModes},
		{"NVIDIA boot reliability", reconcileNvidiaModeset},
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

// printFindings: one line per finding (+ its remedy). without verbose, only
// non-ok lines surface -- a healthy box is quiet. returns warn + fail counts.
func printFindings(fs []finding, verbose bool) (warns, fails int) {
	width := sys.TermWidth()
	printed := 0
	for _, f := range fs {
		switch f.res.status {
		case recWarn:
			warns++
		case recFailed:
			fails++
		}
		if !verbose && (f.res.status == recOK || f.res.status == recNote) {
			continue
		}
		printed++
		w := os.Stdout
		if f.res.status == recWarn || f.res.status == recFailed {
			w = os.Stderr
		}
		fmt.Fprintf(w, "  %s %s\n", statusGlyph(f.res.status), statusName(f))
		if f.res.detail != "" {
			fmt.Fprintln(w, detailStyle(f.res.status, sys.Wrap(f.res.detail, width, "      ")))
		}
		if f.res.remedy != "" && (f.res.status >= recWouldFix || f.res.status == recNote) {
			fmt.Fprintln(w, sys.Brand(sys.Wrap("↳ "+f.res.remedy, width, "      ")))
		}
	}
	if printed == 0 {
		fmt.Println("  " + sys.Green("✓") + " all checks passed")
	}
	return warns, fails
}

func statusGlyph(s recStatus) string {
	switch s {
	case recOK, recFixed:
		return sys.Green("✓")
	case recNote:
		return sys.Dim("·")
	case recWouldFix:
		return sys.Amber("›")
	case recWarn:
		return sys.Amber("!")
	case recFailed:
		return sys.Red("✗")
	}
	return " "
}

func statusName(f finding) string {
	if f.res.status == recOK || f.res.status == recNote {
		return f.name
	}
	name := sys.Bold(f.name)
	if f.res.status == recFixed {
		name += sys.Dim(" (fixed)")
	}
	return name
}

func detailStyle(s recStatus, text string) string {
	if s == recOK || s == recFixed || s == recNote {
		return sys.Dim(text)
	}
	return text
}

func doctorUsage() {
	fmt.Print(`Usage: ryoku doctor [--check] [--verbose] [--report [file]] [--explain]

  (no args)        check, and apply the safe automatic fixes
  --check, -n      report what is wrong without changing anything
  --verbose, -v    also list the checks that passed and advisory notes
  --report [file]  write a shareable diagnostic report for the maintainers
                   (default: ` + reportPath("") + `)
  --explain        ask your cloud model (Groq/OpenRouter) to reason over the report
  --json           emit findings as JSON (read-only; powers the Hub System Check)
`)
}

// Run: check, apply the safe fixes; on anything it can't fix, write a
// maintainer report so the user always has something to share.
func Run(args []string) error {
	checkOnly, wantReport, wantExplain, wantJSON, verboseFlag := false, false, false, false, false
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
		case "--verbose", "-v":
			verboseFlag = true
		case "--json":
			wantJSON = true
		case "-h", "--help":
			doctorUsage()
			return nil
		default:
			return fmt.Errorf("unknown argument: %s (try --help)", a)
		}
	}

	// read-only modes never mutate; showAll also lists ok + advisory notes.
	readOnly := checkOnly || wantReport || wantExplain || wantJSON
	showAll := readOnly || verboseFlag
	findings := runReconcilers(readOnly)
	if wantJSON {
		return emitFindingsJSON(findings)
	}
	warns, fails := printFindings(findings, showAll)

	if wantExplain {
		return explainFindings(findings)
	}

	if wantReport {
		path, err := writeReport(reportTo, findings)
		if err != nil {
			return fmt.Errorf("writing report: %w", err)
		}
		fmt.Printf("\n  %s diagnostic report written to %s\n", sys.Brand("➜"), path)
		fmt.Println("    " + sys.Dim("share it with the maintainers: "+ryokuIssuesURL))
		return nil
	}

	// couldn't fix everything. surface the AI option + a saved report so the
	// user always has a next step and a file to share.
	if warns+fails > 0 {
		path, _ := writeReport("", findings)
		noun := "issue"
		if warns+fails > 1 {
			noun = "issues"
		}
		fmt.Fprintf(os.Stderr, "\n  %s %s\n", sys.Brand("➜"), sys.Bold(fmt.Sprintf("found %d %s", warns+fails, noun)))
		fmt.Fprintf(os.Stderr, "    %s  %s\n", sys.Brand("ryoku doctor --explain"), sys.Dim("AI diagnosis and a suggested fix"))
		if path != "" {
			fmt.Fprintf(os.Stderr, "    %s\n", sys.Dim("report saved: "+path))
		}
	}
	if fails > 0 {
		return fmt.Errorf("%d check(s) failed", fails)
	}
	return nil
}

// findingJSON is the machine-readable shape of a reconciler result, emitted by
// `ryoku doctor --json` so the Hub can render a System Check without parsing
// the human output.
type findingJSON struct {
	Name   string `json:"name"`
	Status string `json:"status"`
	Detail string `json:"detail"`
	Remedy string `json:"remedy,omitempty"`
}

// emitFindingsJSON prints the findings as a JSON array on stdout.
func emitFindingsJSON(findings []finding) error {
	out := make([]findingJSON, 0, len(findings))
	for _, f := range findings {
		out = append(out, findingJSON{
			Name:   f.name,
			Status: f.res.status.label(),
			Detail: f.res.detail,
			Remedy: f.res.remedy,
		})
	}
	b, err := json.MarshalIndent(out, "", "  ")
	if err != nil {
		return err
	}
	fmt.Println(string(b))
	return nil
}

// ---- reconciler: swapfile out of snapshotted subvolumes ----------------------

// reconcileSwapSubvolume: a swapfile inside @ (the snapshotted root) gets
// moved into its own btrfs subvolume. btrfs can't snapshot a subvolume that
// holds an active swapfile, so the old installer layout made every snapper
// snapshot fail. auto-fix only on the exact old layout (one swapfile in a
// plain dir on btrfs); anything else is flagged for a human. no-op once it
// already sits in its own subvolume. skipped on machines that don't snapshot
// root.
func reconcileSwapSubvolume(checkOnly bool) recResult {
	if !sys.Exists("/etc/snapper/configs/root") {
		return okRes("root snapshots not configured, nothing to keep out of them")
	}
	for _, sw := range activeSwapFiles() {
		dir := filepath.Dir(sw.path)
		if !sys.IsBtrfs(dir) || sys.IsBtrfsSubvolumeRoot(dir) {
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

// ---- reconciler: snapper configuration ---------------------------------------

// the snapper "root" config = the safety net behind every ryoku update: the
// pre/post snapshot pair plus the Limine boot-menu entries that make rollback
// work. the installer (installation/backend/lib/snapshots.sh) writes it, but a
// deploy box, an upgrade from an older release, or hand-edited drift can leave
// it missing -- and snapper proceeds silently when it is, so the user believes
// they have rollback when they don't. doctor restores the canonical layout on
// a btrfs root, warns honestly on a non-btrfs root (no snapshots there), stays
// idempotent on a healthy box.
//
// snapperRootConfig mirrors installation/backend/lib/snapshots.sh verbatim:
// keep the two in sync so a doctored box matches a fresh install.
const snapperRootConfig = `# Ryoku snapper config for the root filesystem. Written by ryoku doctor when
# the installer's config is missing (a deploy box, an upgrade from an older
# release, or drift). Keys not listed here fall back to snapper's built-in
# defaults.
SUBVOLUME="/"
FSTYPE="btrfs"
QGROUP=""
SPACE_LIMIT="0.5"
FREE_LIMIT="0.2"
ALLOW_USERS=""
ALLOW_GROUPS=""
SYNC_ACL="no"
BACKGROUND_COMPARISON="yes"
NUMBER_CLEANUP="yes"
NUMBER_MIN_AGE="1800"
NUMBER_LIMIT="10"
NUMBER_LIMIT_IMPORTANT="10"
TIMELINE_CREATE="no"
TIMELINE_CLEANUP="yes"
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="10"
TIMELINE_LIMIT_DAILY="7"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"
EMPTY_PRE_POST_CLEANUP="yes"
EMPTY_PRE_POST_MIN_AGE="1800"
`

const snapperConfdRoot = `## Path: System/Snapper
## Type: string
## Default: ""
# Snapper configs the systemd units and pacman hooks operate on.
SNAPPER_CONFIGS="root"
`

// snapperOutcome: what planSnapper hands to reconcileSnapper. ok = leave the
// box alone; the two warn variants surface as-is; create writes the canonical
// layout.
type snapperOutcome int

const (
	snapperOK snapperOutcome = iota
	snapperWarnNotBtrfs
	snapperWarnInconsistent
	snapperCreate
	snapperWarnMissingPkgs
	snapperOptedOut
)

// snapperState: the slice of the filesystem reconcileSnapper looks at, lifted
// to a value so planSnapper is unit-testable without real /etc or running
// snapper/btrfs.
type snapperState struct {
	rootIsBtrfs         bool
	configExists        bool
	optedOut            bool
	snapshotsExists     bool
	snapshotsIsSubvol   bool
	snapshotsMode       os.FileMode
	confdExists         bool
	confdContents       string
	snapperInstalled    bool
	snapPacInstalled    bool
	limineInstalled     bool
	limineSyncInstalled bool
	limineSyncEnabled   bool
}

// planSnapper picks the branch from observed state. pure, no IO. the
// "configured" branch runs the same consistency checks the old reconciler
// did, so a healthy box still reads ok.
func planSnapper(s snapperState) (snapperOutcome, []string) {
	if !s.configExists {
		if !s.rootIsBtrfs {
			return snapperWarnNotBtrfs, nil
		}
		// the installer records an explicit "no snapshots" choice
		// (RYOKU_SUBVOL_SNAPSHOTS=0) as /etc/ryoku/snapshots-disabled; creating
		// the layout anyway would silently revert it on the first update. an
		// existing config always wins over a stale marker.
		if s.optedOut {
			return snapperOptedOut, nil
		}
		if !s.snapperInstalled {
			return snapperWarnMissingPkgs, nil
		}
		return snapperCreate, nil
	}
	var problems []string
	if s.snapshotsExists && !s.snapshotsIsSubvol {
		problems = append(problems, "/.snapshots is a plain directory, not a btrfs subvolume")
	}
	if s.snapshotsExists && s.snapshotsMode != 0o750 {
		problems = append(problems, fmt.Sprintf("/.snapshots is mode %04o, expected 0750", s.snapshotsMode))
	}
	if s.confdExists && !strings.Contains(s.confdContents, "root") {
		problems = append(problems, "/etc/conf.d/snapper does not list the root config (timers and hooks will skip it)")
	}
	if !s.snapperInstalled {
		problems = append(problems, "snapper is not installed; the root config exists but cannot be used (sudo pacman -S snapper)")
	}
	if !s.snapPacInstalled {
		problems = append(problems, "snap-pac is not installed, so pacman transactions are not auto-snapshotted (sudo pacman -S snap-pac)")
	}
	// only meaningful under Limine; a GRUB box (converted CachyOS and the
	// like) is healthy without it and must not warn forever.
	if s.limineInstalled {
		if !s.limineSyncInstalled {
			problems = append(problems, "limine-snapper-sync is not installed, so snapshots are not in the Limine boot menu (ryoku-pkg-aur-add limine-snapper-sync)")
		} else if !s.limineSyncEnabled {
			problems = append(problems, "limine-snapper-sync.service is disabled, so new snapshots never reach the Limine boot menu (sudo systemctl enable --now limine-snapper-sync.service)")
		}
	}
	if len(problems) == 0 {
		return snapperOK, nil
	}
	return snapperWarnInconsistent, problems
}

// gatherSnapperState reads /etc + /.snapshots into a snapperState. all
// non-privileged stats and world-readable files; privileged writes happen
// later in the create branch under sudo, like every other reconciler.
func gatherSnapperState() snapperState {
	s := snapperState{
		rootIsBtrfs:         sys.IsBtrfs("/"),
		configExists:        sys.Exists("/etc/snapper/configs/root"),
		optedOut:            sys.Exists("/etc/ryoku/snapshots-disabled"),
		snapperInstalled:    sys.Has("snapper"),
		snapPacInstalled:    sys.PkgInstalled("snap-pac"),
		limineInstalled:     sys.PkgInstalled("limine"),
		limineSyncInstalled: sys.PkgInstalled("limine-snapper-sync"),
		limineSyncEnabled:   sys.UnitEnabled("limine-snapper-sync.service"),
	}
	if fi, err := os.Stat("/.snapshots"); err == nil {
		s.snapshotsExists = true
		s.snapshotsMode = fi.Mode().Perm()
		s.snapshotsIsSubvol = sys.IsBtrfsSubvolumeRoot("/.snapshots")
	}
	if b, err := os.ReadFile("/etc/conf.d/snapper"); err == nil {
		s.confdExists = true
		s.confdContents = string(b)
	}
	return s
}

// reconcileSnapper converges the snapper "root" config. btrfs root + no config
// -> write the canonical installer layout. non-btrfs root -> warn honestly
// instead of silently ok. healthy box -> consistency checks gate "ok".
func reconcileSnapper(checkOnly bool) recResult {
	st := gatherSnapperState()
	outcome, problems := planSnapper(st)
	switch outcome {
	case snapperWarnNotBtrfs:
		return warnRes("root filesystem is not btrfs; snapshot and rollback are unavailable on this machine")
	case snapperWarnMissingPkgs:
		return warnRes("root is btrfs but snapper is not installed; snapshots and rollback are off").
			withFix("sudo pacman -S snapper snap-pac, then ryoku doctor")
	case snapperOptedOut:
		return okRes("snapshots were declined at install (/etc/ryoku/snapshots-disabled); delete the marker and run `ryoku doctor` to enable them")
	case snapperCreate:
		if checkOnly {
			return wouldRes("snapper root config is missing; snapshots and rollback are off").
				withFix("ryoku doctor (creates the snapper root config)")
		}
		return createSnapperRootConfig(st)
	case snapperWarnInconsistent:
		return warnRes("%s", strings.Join(problems, "; ")).
			withFix("see https://wiki.archlinux.org/title/Snapper")
	}
	return okRes("snapper root config is consistent")
}

// createSnapperRootConfig lays the installer's layout down on a live box.
// mirrors installation/backend/lib/snapshots.sh:
//   - /.snapshots = btrfs subvolume, owned root:root, mode 0750.
//   - write /etc/snapper/configs/root.
//   - register "root" in /etc/conf.d/snapper without dropping siblings.
//   - best-effort enable snapper-cleanup.timer (+ limine-snapper-sync.service
//     when its unit is present).
//
// a pre-existing plain-directory /.snapshots is left to a human: it might
// hold user data, and the risk of rmdir clobbering it isn't worth saving the
// extra command.
func createSnapperRootConfig(st snapperState) recResult {
	var actions []string

	switch {
	case !st.snapshotsExists:
		if err := sys.Run("sudo", "btrfs", "subvolume", "create", "/.snapshots"); err != nil {
			return failRes("creating /.snapshots subvolume: %v", err).
				withFix("sudo btrfs subvolume create /.snapshots, then re-run ryoku doctor")
		}
		actions = append(actions, "/.snapshots subvolume")
	case !st.snapshotsIsSubvol:
		return warnRes("/.snapshots exists as a plain directory; remove or convert it before the snapper config can be created").
			withFix("inspect /.snapshots, then `sudo rmdir /.snapshots && sudo btrfs subvolume create /.snapshots` and re-run ryoku doctor")
	}

	if err := sys.Run("sudo", "chmod", "0750", "/.snapshots"); err != nil {
		return failRes("chmod /.snapshots: %v", err)
	}
	if err := sys.Run("sudo", "chown", "root:root", "/.snapshots"); err != nil {
		return failRes("chown /.snapshots: %v", err)
	}

	if err := writeRootFile("/etc/snapper/configs/root", snapperRootConfig, "0640"); err != nil {
		return failRes("writing /etc/snapper/configs/root: %v", err)
	}
	actions = append(actions, "/etc/snapper/configs/root")

	newConfd, changed := mergedConfdRoot(st.confdExists, st.confdContents)
	if changed {
		if err := writeRootFile("/etc/conf.d/snapper", newConfd, "0644"); err != nil {
			return failRes("writing /etc/conf.d/snapper: %v", err)
		}
		actions = append(actions, "/etc/conf.d/snapper")
	}

	// services: best-effort. a healthy install has both; an offline AUR install
	// can be missing limine-snapper-sync, and a failure here doesn't undo the
	// config we just wrote.
	_ = sys.Run("sudo", "systemctl", "enable", "--now", "snapper-cleanup.timer")
	if sys.Exists("/usr/lib/systemd/system/limine-snapper-sync.service") {
		_ = sys.Run("sudo", "systemctl", "enable", "--now", "limine-snapper-sync.service")
	}

	return fixedRes("created snapper root config: %s", strings.Join(actions, ", "))
}

// mergedConfdRoot returns the desired /etc/conf.d/snapper contents + whether
// they differ from the current file. missing file -> canonical snippet.
// SNAPPER_CONFIGS already lists root -> unchanged. SNAPPER_CONFIGS lists other
// configs -> append "root", keep them. file present, no SNAPPER_CONFIGS line
// -> add one. split-on-whitespace tolerates both "a b" and single-name styles
// snapper accepts in the wild.
func mergedConfdRoot(present bool, current string) (string, bool) {
	if !present {
		return snapperConfdRoot, true
	}
	lines := strings.Split(current, "\n")
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if !strings.HasPrefix(trimmed, "SNAPPER_CONFIGS=") {
			continue
		}
		value := strings.Trim(strings.TrimPrefix(trimmed, "SNAPPER_CONFIGS="), `"`)
		configs := strings.Fields(value)
		for _, c := range configs {
			if c == "root" {
				return current, false
			}
		}
		configs = append(configs, "root")
		lines[i] = fmt.Sprintf(`SNAPPER_CONFIGS="%s"`, strings.Join(configs, " "))
		return strings.Join(lines, "\n"), true
	}
	if current != "" && !strings.HasSuffix(current, "\n") {
		current += "\n"
	}
	return current + `SNAPPER_CONFIGS="root"` + "\n", true
}

// writeRootFile: stage contents in a temp file, then `sudo install -D` into
// place at the given mode, owned root:root, so a regular-user `ryoku doctor`
// still converges /etc. install -D makes the parent dir in one shot, same
// pattern as the other privileged reconcilers that go through sudo.
func writeRootFile(path, contents, mode string) error {
	tmp, err := os.CreateTemp("", "ryoku-snapper-*")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name())
	if _, err := tmp.WriteString(contents); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return sys.Run("sudo", "install", "-D", "-m", mode, "-o", "root", "-g", "root", tmp.Name(), path)
}

// ---- reconciler: stale pacman lock -------------------------------------------

func reconcilePacmanLock(checkOnly bool) recResult {
	const lock = "/var/lib/pacman/db.lck"
	if !sys.Exists(lock) {
		return okRes("no stale pacman lock")
	}
	if processRunning("pacman") {
		return okRes("pacman is running; lock is in use")
	}
	if checkOnly {
		return wouldRes("stale pacman lock present (no pacman running)").withFix("sudo rm %s", lock)
	}
	if err := sys.Run("sudo", "rm", "-f", lock); err != nil {
		return failRes("could not remove stale lock: %v", err).withFix("sudo rm %s", lock)
	}
	return fixedRes("removed stale pacman lock")
}

// ---- reconciler: stale update run-state --------------------------------------

// reconcileStaleUpdateRun clears the run-state file a crashed `ryoku update`
// left in "running" (or an unanswered "prompt"): the shell's update island and
// the Hub keep rendering that phantom run for the rest of the session. A live
// `ryoku update` (stage 1 or --stage2) owns the file and is left alone; so is
// the update this doctor may itself be running inside (the process match).
// updateProcessLive: is a `ryoku update` (stage 1 or --stage2) running right
// now? A package var so tests can stub it: a real pgrep scan is neither
// hermetic (a dev's live update flips the result) nor guaranteed cheap.
var updateProcessLive = func() bool {
	return exec.Command("pgrep", "-f", "ryoku update").Run() == nil
}

func reconcileStaleUpdateRun(checkOnly bool) recResult {
	dir := os.Getenv("XDG_RUNTIME_DIR")
	if dir == "" {
		dir = "/tmp"
	}
	path := filepath.Join(dir, "ryoku-update.json")
	b, err := os.ReadFile(path)
	if err != nil {
		return okRes("no update run-state")
	}
	var st struct {
		Phase string `json:"phase"`
	}
	if json.Unmarshal(b, &st) != nil || (st.Phase != "running" && st.Phase != "prompt") {
		return okRes("update run-state is settled")
	}
	if updateProcessLive() {
		return okRes("an update is running; run-state is live")
	}
	if checkOnly {
		return wouldRes("update island stuck on a crashed run (phase %s)", st.Phase).withFix("rm %s", path)
	}
	idle := []byte(`{"phase":"idle"}`)
	if os.WriteFile(path+".tmp", idle, 0o644) == nil && os.Rename(path+".tmp", path) == nil {
		return fixedRes("cleared a crashed update's run-state")
	}
	if err := os.Remove(path); err != nil {
		return failRes("could not clear the stale run-state: %v", err).withFix("rm %s", path)
	}
	return fixedRes("cleared a crashed update's run-state")
}

// ---- reconciler: stale install crypt mapper ----------------------------------

// reconcileStaleCryptMapper clears a /dev/mapper/root the installer left open.
// ryoku-install opens the encrypted root under that name; a failed run (or a
// retry) leaves it held, so the next `cryptsetup open ... root` aborts with
// "Device root already exists". Closing the orphan frees the name.
// Safe: a "root" node backing a live mount (the running root) is never touched,
// only a true orphan with no mount; closing a LUKS mapper only re-locks it.
func reconcileStaleCryptMapper(checkOnly bool) recResult {
	nodes := cryptMapperNodes()
	if len(nodes) == 0 {
		return okRes("no crypt mappers present")
	}
	stale := staleInstallMapper(nodes, mountSourceOf("/"), mountedSources())
	if stale == "" {
		return okRes("no orphaned install crypt mapper")
	}
	node := "/dev/mapper/" + stale
	if checkOnly {
		return wouldRes("orphaned crypt mapper %s from a failed install blocks `cryptsetup open ... %s`", node, stale).
			withFix("sudo cryptsetup close %s", stale)
	}
	if err := sys.Run("sudo", "cryptsetup", "close", stale); err != nil {
		return failRes("could not close orphaned crypt mapper %s: %v", node, err).
			withFix("sudo cryptsetup close %s", stale)
	}
	return fixedRes("closed orphaned crypt mapper %s left by a failed install", node)
}

// staleInstallMapper returns "root" only when /dev/mapper/root is a true orphan:
// present, not backing "/", and holding no mount. pure, so the safety gate is
// testable without device-mapper.
func staleInstallMapper(cryptNodes []string, rootSource string, mountedSources map[string]bool) string {
	const node = "/dev/mapper/root"
	present := false
	for _, m := range cryptNodes {
		if m == node {
			present = true
			break
		}
	}
	if !present {
		return ""
	}
	if rootSource == node || mountedSources[node] {
		return "" // backs a live mount: the running root or a mounted target
	}
	return "root"
}

// cryptMapperNodes lists the device-mapper nodes of type crypt as
// /dev/mapper/<name>. empty when dmsetup is absent, unprivileged, or finds none.
func cryptMapperNodes() []string {
	out, err := sys.RunOut("dmsetup", "ls", "--target", "crypt")
	if err != nil {
		return nil
	}
	return parseCryptMapperNodes(out)
}

// parseCryptMapperNodes maps `dmsetup ls --target crypt` lines to /dev/mapper
// paths; "No devices found" yields none.
func parseCryptMapperNodes(out string) []string {
	var nodes []string
	for _, ln := range nonEmptyLines(out) {
		f := strings.Fields(ln)
		if len(f) == 0 || f[0] == "No" {
			continue
		}
		nodes = append(nodes, "/dev/mapper/"+f[0])
	}
	return nodes
}

// mountSourceOf returns the bare backing device of a mountpoint, btrfs
// subvolume suffix stripped (/dev/mapper/root[/@] -> /dev/mapper/root).
func mountSourceOf(path string) string {
	out, _ := sys.RunOut("findmnt", "-n", "-o", "SOURCE", path)
	return baseSource(out)
}

// mountedSources is the set of block devices with a current mount, subvolume
// suffixes stripped, so a crypt mapper backing any live mount is recognizable.
func mountedSources() map[string]bool {
	m := map[string]bool{}
	out, _ := sys.RunOut("findmnt", "-rn", "-o", "SOURCE")
	for _, ln := range nonEmptyLines(out) {
		if s := baseSource(ln); s != "" {
			m[s] = true
		}
	}
	return m
}

// baseSource trims findmnt's btrfs subvolume suffix:
// "/dev/mapper/root[/@home]" -> "/dev/mapper/root".
func baseSource(s string) string {
	s = strings.TrimSpace(s)
	if i := strings.IndexByte(s, '['); i >= 0 {
		s = s[:i]
	}
	return s
}

// ---- reconciler: ryoku package channel + keyring -----------------------------

func reconcileRyokuChannel(_ bool) recResult {
	if !sys.PkgInstalled("ryoku-desktop") {
		return okRes("not a packaged install (desktop runs from a checkout)")
	}
	conf, _ := os.ReadFile("/etc/pacman.conf")
	if !strings.Contains(string(conf), "[ryoku]") {
		return warnRes("ryoku-desktop is installed but the [ryoku] repo is not in pacman.conf; updates will not arrive").
			withFix("add the [ryoku] repo (see docs/development.md)")
	}
	if !sys.PkgInstalled("ryoku-keyring") {
		return warnRes("the [ryoku] repo is configured but ryoku-keyring is missing; signatures will fail").
			withFix("sudo pacman -S ryoku-keyring")
	}
	return okRes("ryoku package channel configured")
}

// ---- reconciler: wallpaper daemons -------------------------------------------

// reconcileWallpaperDaemon heals a Ryoku desktop missing awww, the AUR image
// wallpaper daemon the shell drives (swww renamed upstream). It is AUR-only, so
// `ryoku update` (pacman) never pulls it, and a box that predates it -- or one
// upgraded across the swww->awww rename -- silently can't set a static wallpaper.
// Live (video) wallpapers ride ryoku-livewall, which ships inside ryoku-shell
// (the [ryoku] repo) and so reaches boxes on `ryoku update` with no reconcile. In
// fix mode the one-shot AUR add IS the fix; `--check` reports what it would add.
func reconcileWallpaperDaemon(checkOnly bool) recResult {
	if !sys.Exists(filepath.Join(sys.Home(), ".config", "hypr")) && !sys.Has("Hyprland") {
		return okRes("not a Hyprland desktop")
	}
	if sys.Has("awww") || sys.Has("swww") {
		return okRes("wallpaper daemon present")
	}
	broke := "static wallpapers and the still under live ones may not work"
	if checkOnly {
		return wouldRes("missing awww; %s", broke).withFix("ryoku-pkg-aur-add awww-git")
	}
	if err := sys.Run("ryoku-pkg-aur-add", "awww-git"); err != nil {
		return failRes("could not install awww-git: %v", err).withFix("ryoku-pkg-aur-add awww-git")
	}
	return fixedRes("installed the wallpaper daemon: awww-git")
}

// ---- reconciler: Material Symbols icon font ------------------------------------

// reconcileIconFont converges the icon font onto boxes that predate it being a
// ryoku-desktop dependency: every shell glyph is a Material Symbols ligature
// (MaterialIcon.qml), so without the font each icon renders as its name in
// plain text ("network_wifi"). the package depend heals packaged boxes on
// their next full update; this heals git-channel boxes and anyone already
// broken today.
func reconcileIconFont(checkOnly bool) recResult {
	if !sys.Exists(filepath.Join(sys.Home(), ".config", "hypr")) && !sys.Has("Hyprland") {
		return okRes("not a Hyprland desktop")
	}
	if anyPkgInstalled("ttf-material-symbols-variable", "ttf-material-symbols-variable-git") {
		return okRes("Material Symbols icon font installed")
	}
	if checkOnly {
		return wouldRes("Material Symbols font missing; every shell icon renders as its ligature name").
			withFix("ryoku doctor installs ttf-material-symbols-variable")
	}
	if err := sys.Sudo("pacman", "-S", "--needed", "--noconfirm", "ttf-material-symbols-variable"); err != nil {
		return failRes("could not install ttf-material-symbols-variable: %v", err).
			withFix("sudo pacman -S ttf-material-symbols-variable")
	}
	return fixedRes("installed the Material Symbols icon font; `ryoku reload` picks it up")
}

// ---- reconciler: stale dev/recovery residue ------------------------------------

// reconcileDevResidue clears home-installed Ryoku artifacts off a packaged box.
// deploy.sh (the dev loop, and `ryoku recovery`) installs binaries into
// ~/.local/bin and QML modules into ~/.local/lib/qt6/qml; both outrank the
// packaged copies on PATH and the QML import path, so once the box is back on
// the pacman channel the leftovers pin it to whatever vintage last deployed
// them and every later package update is silently shadowed. a checkout box
// (git channel) IS the dev loop: left alone.
func reconcileDevResidue(checkOnly bool) recResult {
	if sys.ResolveRepo() != "" {
		return okRes("checkout box; home-deployed artifacts are the live desktop")
	}
	if !sys.PkgInstalled("ryoku-desktop") {
		return okRes("not a packaged install")
	}
	var residue []string
	if qml := filepath.Join(sys.Home(), ".local", "lib", "qt6", "qml", "Ryoku"); sys.Exists(qml) {
		residue = append(residue, qml)
	}
	for _, b := range []string{"ryoku", "ryoku-shell", "ryoku-hub", "ryoku-rashin"} {
		p := filepath.Join(sys.Home(), ".local", "bin", b)
		if sys.Exists(p) && sys.Exists("/usr/bin/"+b) {
			residue = append(residue, p)
		}
	}
	if len(residue) == 0 {
		return okRes("no home-deployed artifacts shadowing the packages")
	}
	if checkOnly {
		return wouldRes("stale home-deployed artifacts shadow the packaged install: %s", strings.Join(residue, ", ")).
			withFix("ryoku doctor removes them; the packaged copies take over on the next reload")
	}
	for _, p := range residue {
		_ = os.RemoveAll(p)
	}
	return fixedRes("removed %d home-deployed artifact(s) shadowing the packaged install; `ryoku reload` switches to the packaged shell", len(residue))
}

// ---- reconciler: shell config schema -------------------------------------------

// legacyIslandKeys: pill-era knobs the popouts rework retired. their presence
// marks a ~/.config/ryoku/shell.json seeded before the rework, whose values
// point the shell at a face that no longer exists (islandStyle "floating",
// barEnabled false): an updated box would come up with no bar and no resting
// island at all. materialize never touches this file, so only doctor can
// converge it.
var legacyIslandKeys = []string{
	"islandWidth", "islandHeight", "islandRestCorner", "islandOpenCorner",
	"islandGap", "islandSmoothing", "islandOpacity", "islandStyle", "islandAutohide",
}

// shellConfigClamps: geometry knobs the renderer consumes raw; a value outside
// these ranges draws a broken frame (the Hub sliders stay well inside them).
var shellConfigClamps = map[string][2]float64{
	"frameBorder":    {50, 120},
	"frameRadius":    {0, 32},
	"frameSmoothing": {1, 32},
	"barHeight":      {16, 64},
	"fontScale":      {0.7, 1.6},
}

func reconcileShellConfig(checkOnly bool) recResult {
	path := filepath.Join(sys.ConfigHome(), "ryoku", "shell.json")
	raw, err := os.ReadFile(path)
	if err != nil {
		return okRes("no shell.json yet (seeded on first shell run)")
	}
	migrated, changes, err := migrateShellConfig(raw)
	if err != nil {
		return warnRes("shell.json does not parse (%v); the shell falls back to defaults", err).
			withFix("delete %s to re-seed it", path)
	}
	if len(changes) == 0 {
		return okRes("shell.json is on the current schema")
	}
	if checkOnly {
		return wouldRes("shell.json carries pre-rework state: %s", strings.Join(changes, "; ")).
			withFix("ryoku doctor migrates it in place")
	}
	tmp := path + ".ryoku-tmp"
	if err := os.WriteFile(tmp, migrated, 0o644); err != nil {
		return failRes("could not write %s: %v", tmp, err)
	}
	if err := os.Rename(tmp, path); err != nil {
		os.Remove(tmp)
		return failRes("could not replace %s: %v", path, err)
	}
	return fixedRes("migrated shell.json to the current schema: %s", strings.Join(changes, "; "))
}

// migrateShellConfig drops retired pill-era keys, revives the bar they pointed
// at, and clamps out-of-range geometry. pure, so it is unit-testable; returns
// the rewritten JSON and a human summary of what changed (empty = no change).
func migrateShellConfig(raw []byte) ([]byte, []string, error) {
	var cfg map[string]any
	if err := json.Unmarshal(raw, &cfg); err != nil {
		return nil, nil, err
	}
	var changes []string
	legacy := false
	for _, k := range legacyIslandKeys {
		if _, ok := cfg[k]; ok {
			delete(cfg, k)
			legacy = true
		}
	}
	if legacy {
		changes = append(changes, "dropped the retired island knobs")
		// the resting island those files disabled the bar in favour of no
		// longer exists; without the bar the rework has no shell face at all.
		if on, ok := cfg["barEnabled"].(bool); ok && !on {
			cfg["barEnabled"] = true
			changes = append(changes, "enabled the bar (the resting island it replaced is gone)")
		}
		if _, ok := cfg["barPosition"]; !ok {
			cfg["barPosition"] = "top"
		}
	}
	for k, r := range shellConfigClamps {
		v, ok := cfg[k].(float64)
		if !ok {
			continue
		}
		if v < r[0] || v > r[1] {
			cfg[k] = min(max(v, r[0]), r[1])
			changes = append(changes, fmt.Sprintf("clamped %s %g into [%g, %g]", k, v, r[0], r[1]))
		}
	}
	if len(changes) == 0 {
		return nil, nil, nil
	}
	out, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return nil, nil, err
	}
	return append(out, '\n'), changes, nil
}

// ---- reconciler: desktop session components ----------------------------------

func reconcileSessionComponents(_ bool) recResult {
	if !sys.Exists(filepath.Join(sys.Home(), ".config", "hypr")) && !sys.Has("Hyprland") {
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

// ---- reconciler: desktop portal routing ----------------------------------------

// portalConfigCandidates lists every file xdg-desktop-portal consults on a
// Hyprland session, highest precedence first (portals.conf(5)): user config,
// XDG_CONFIG_DIRS, /etc, user data, XDG_DATA_DIRS. in each location the
// desktop-specific name is read before the generic one, and the first file
// that exists wins outright, nothing merges. that order is the trap: a
// user-level generic portals.conf beats the packaged hyprland-portals.conf.
func portalConfigCandidates(home string) []string {
	var dirs []string
	if v := os.Getenv("XDG_CONFIG_HOME"); v != "" {
		dirs = append(dirs, v)
	} else {
		dirs = append(dirs, filepath.Join(home, ".config"))
	}
	confDirs := os.Getenv("XDG_CONFIG_DIRS")
	if confDirs == "" {
		confDirs = "/etc/xdg"
	}
	dirs = append(dirs, strings.Split(confDirs, ":")...)
	dirs = append(dirs, "/etc")
	if v := os.Getenv("XDG_DATA_HOME"); v != "" {
		dirs = append(dirs, v)
	} else {
		dirs = append(dirs, filepath.Join(home, ".local/share"))
	}
	dataDirs := os.Getenv("XDG_DATA_DIRS")
	if dataDirs == "" {
		dataDirs = "/usr/local/share:/usr/share"
	}
	dirs = append(dirs, strings.Split(dataDirs, ":")...)
	dirs = append(dirs, "/usr/share")
	var out []string
	seen := map[string]bool{}
	for _, d := range dirs {
		if d == "" || seen[d] {
			continue
		}
		seen[d] = true
		out = append(out,
			filepath.Join(d, "xdg-desktop-portal", "hyprland-portals.conf"),
			filepath.Join(d, "xdg-desktop-portal", "portals.conf"))
	}
	return out
}

// portalRoutesHyprland: does this config hand the default portal role to the
// hyprland backend? per-interface overrides next to a sane default are a
// deliberate user tweak and stay untouched.
func portalRoutesHyprland(content string) bool {
	section := ""
	for _, ln := range strings.Split(content, "\n") {
		t := strings.TrimSpace(ln)
		if strings.HasPrefix(t, "[") && strings.HasSuffix(t, "]") {
			section = t
			continue
		}
		if section != "[preferred]" {
			continue
		}
		k, v, ok := strings.Cut(t, "=")
		if !ok || strings.TrimSpace(k) != "default" {
			continue
		}
		for _, b := range strings.Split(v, ";") {
			if strings.TrimSpace(b) == "hyprland" {
				return true
			}
		}
	}
	return false
}

// reconcilePortalRouting keeps xdg-desktop-portal pointed at the hyprland
// backend. a migrated box can carry a leftover user or /etc portals.conf that
// outranks the packaged hyprland one; the gnome backend it names hangs under
// Hyprland and every app that reads the settings portal at startup waits out
// a ~25s D-Bus timeout ("apps are slow to open"). heals boxes converted
// before the installer started moving the user file aside, and the /etc case.
func reconcilePortalRouting(checkOnly bool) recResult {
	if !sys.Exists(filepath.Join(sys.Home(), ".config", "hypr")) && !sys.Has("Hyprland") {
		return okRes("not a Hyprland desktop")
	}
	// the first existing candidate is the one the portal loads, so every
	// misrouted file ahead of a healthy one has to move aside.
	var offenders []string
	healthy := ""
	for _, p := range portalConfigCandidates(sys.Home()) {
		b, err := os.ReadFile(p)
		if err != nil {
			continue
		}
		if portalRoutesHyprland(string(b)) {
			healthy = p
			break
		}
		offenders = append(offenders, p)
	}
	if len(offenders) == 0 {
		if healthy == "" {
			// no config at all: xdg-desktop-portal-hyprland is missing and the
			// session components check already flags that.
			return okRes("no portal routing config found")
		}
		return okRes("portal routing follows %s", healthy)
	}
	if healthy == "" {
		return warnRes("no config routes portals to the hyprland backend; screenshare and portal dialogs cannot work").
			withFix("sudo pacman -S xdg-desktop-portal-hyprland")
	}
	list := strings.Join(offenders, ", ")
	if checkOnly {
		return wouldRes("%s routes portals away from hyprland; apps stall ~25s at launch and screenshare breaks", list).
			withFix("ryoku doctor moves the file(s) aside and restarts the portal")
	}
	for _, p := range offenders {
		bak := p + ".ryoku-bak"
		var err error
		if strings.HasPrefix(p, sys.Home()+string(os.PathSeparator)) {
			err = os.Rename(p, bak)
		} else {
			err = sys.Sudo("mv", p, bak)
		}
		if err != nil {
			return failRes("could not move %s aside: %v", p, err).withFix("mv %s %s", p, bak)
		}
	}
	// a hung foreign backend keeps its stall alive until it dies. best-effort
	// and quiet: outside a session the next login picks the routing up anyway.
	for _, u := range []string{"xdg-desktop-portal-gnome.service", "xdg-desktop-portal-kde.service",
		"xdg-desktop-portal-wlr.service", "xdg-desktop-portal-lxqt.service"} {
		_ = exec.Command("systemctl", "--user", "stop", u).Run()
	}
	_ = exec.Command("systemctl", "--user", "try-restart", "xdg-desktop-portal.service").Run()
	return fixedRes("moved %s aside; the portal now follows %s", list, healthy)
}

// ---- reconciler: cursor theme ------------------------------------------------

// reconcileCursorTheme flags a Ryoku desktop with no Bibata cursor theme.
// shipped XCURSOR_THEME default (env.lua + Ryoku Settings) = Bibata-Modern-Ice,
// and the AUR set installs the whole Bibata family. but a failed source build
// or a dev checkout (deploy.sh installs no AUR packages) can leave the cursor
// picker with only a single fallback. the -bin package is prebuilt, so the
// fix never has to compile.
func reconcileCursorTheme(_ bool) recResult {
	if !sys.Exists(filepath.Join(sys.Home(), ".config", "hypr")) && !sys.Has("Hyprland") {
		return okRes("not a Hyprland desktop")
	}
	if anyPkgInstalled("bibata-cursor-theme-bin", "bibata-cursor-theme") {
		return okRes("Bibata cursor themes installed")
	}
	return warnRes("Ryoku's Bibata cursor themes are missing; the cursor picker has only fallbacks").
		withFix("ryoku-pkg-aur-add bibata-cursor-theme-bin")
}

// ---- reconciler: SDDM greeter theme readable ---------------------------------

const greeterThemeDir = "/usr/share/sddm/themes/ryoku"

// greeterThemeHealthy: can the unprivileged `sddm` greeter read the theme? sddm
// is neither the owner nor a group member, so readability rides on the world
// bits -- the theme dir needs o+rx and Main.qml o+r. root ownership is required
// too, so a regular user can't swap the QML the login screen loads.
func greeterThemeHealthy(ownerUID uint32, dirPerm, mainPerm os.FileMode) bool {
	return ownerUID == 0 && dirPerm&0o005 == 0o005 && mainPerm&0o004 != 0
}

// reconcileGreeterTheme keeps the SDDM greeter theme readable by the sddm user.
// `ryoku-hub lock set` copies the picked skin into the fixed greeter dir; a skin
// pulled from the catalogue downloads into an os.MkdirTemp dir (always 0700,
// user-owned), so an older `cp -a` left the greeter unreadable to sddm and SDDM
// silently fell back to its embedded theme on every boot. installGreeter now
// normalizes on write; this backports the fix to boxes that already picked a
// skin. only ever touches the one fixed Ryoku greeter dir.
func reconcileGreeterTheme(checkOnly bool) recResult {
	di, err := os.Stat(greeterThemeDir)
	if err != nil {
		return okRes("no Ryoku greeter theme installed")
	}
	mi, err := os.Stat(filepath.Join(greeterThemeDir, "Main.qml"))
	if err != nil {
		return okRes("no Ryoku greeter theme installed")
	}
	st, ok := di.Sys().(*syscall.Stat_t)
	if !ok {
		return okRes("greeter theme ownership not checkable")
	}
	if greeterThemeHealthy(st.Uid, di.Mode().Perm(), mi.Mode().Perm()) {
		return okRes("greeter theme readable by the sddm greeter")
	}
	fix := fmt.Sprintf("sudo chown -R root:root %s && sudo chmod -R a+rX %s", greeterThemeDir, greeterThemeDir)
	if checkOnly {
		return wouldRes("greeter theme unreadable by the sddm greeter; SDDM falls back to its default").withFix(fix)
	}
	if err := sys.Run("sudo", "chown", "-R", "root:root", greeterThemeDir); err != nil {
		return failRes("could not fix greeter theme ownership: %v", err).withFix(fix)
	}
	if err := sys.Run("sudo", "chmod", "-R", "a+rX", greeterThemeDir); err != nil {
		return failRes("could not fix greeter theme permissions: %v", err).withFix(fix)
	}
	return fixedRes("normalized greeter theme so the sddm greeter can read it")
}

// ---- reconciler: fastfetch readout emblem ------------------------------------

const fastfetchEmblem = "fastfetch-emblem.png"

// fastfetchLogoSource pulls the logo image path out of a fastfetch config.jsonc
// (JSONC, so it won't json.Unmarshal). the readout declares exactly one
// "source", the logo image; comment lines are skipped. false when there is no
// source line, i.e. no Ryoku fastfetch logo to keep alive.
func fastfetchLogoSource(cfg string) (string, bool) {
	for _, ln := range strings.Split(cfg, "\n") {
		ln = strings.TrimSpace(ln)
		if strings.HasPrefix(ln, "//") || !strings.HasPrefix(ln, `"source"`) {
			continue
		}
		colon := strings.IndexByte(ln, ':')
		if colon < 0 {
			continue
		}
		rest := ln[colon+1:]
		a := strings.IndexByte(rest, '"')
		if a < 0 {
			continue
		}
		b := strings.IndexByte(rest[a+1:], '"')
		if b < 0 {
			continue
		}
		return rest[a+1 : a+1+b], true
	}
	return "", false
}

// expandTilde resolves a leading ~ to the home dir, matching how fastfetch
// expands the logo source at runtime.
func expandTilde(p string) string {
	switch {
	case p == "~":
		return sys.Home()
	case strings.HasPrefix(p, "~/"):
		return filepath.Join(sys.Home(), p[2:])
	}
	return p
}

// reconcileFastfetchEmblem keeps the branded fastfetch readout off the stock
// Arch logo. config.jsonc draws a kitty-direct logo from an image file; when
// that file is missing fastfetch SILENTLY drops to its built-in distro logo
// (empty stderr), so the terminal greets with Arch instead of the Ryoku emblem.
// the emblem now materializes into the config dir beside config.jsonc, but a box
// that updated before that shipped points config.jsonc at an emblem it never
// received. restore it from the packaged base config tree, the same file
// `ryoku materialize` lays. no-op when the readout resolves, when the logo is
// user-customized, or on a box with no Ryoku fastfetch config.
func reconcileFastfetchEmblem(checkOnly bool) recResult {
	src, ok := fastfetchLogoSource(readFileSafe(filepath.Join(sys.ConfigHome(), "fastfetch", "config.jsonc")))
	if !ok {
		return okRes("no Ryoku fastfetch logo configured")
	}
	if filepath.Base(src) != fastfetchEmblem {
		return okRes("fastfetch logo is user-customized")
	}
	dst := expandTilde(src)
	if sys.Exists(dst) {
		return okRes("fastfetch emblem present")
	}
	// the canonical copy materialize lays; absent only on a box still on the
	// pre-fix package, where the cure is to pull it first.
	base := filepath.Join(sys.BaseConfigDir(), "fastfetch", fastfetchEmblem)
	if !sys.Exists(base) {
		return warnRes("fastfetch emblem missing (%s); the readout shows the Arch logo", dst).
			withFix("ryoku update")
	}
	if checkOnly {
		return wouldRes("fastfetch emblem missing (%s); the readout shows the Arch logo", dst).
			withFix("ryoku materialize")
	}
	if err := sys.CopyFile(base, dst); err != nil {
		return failRes("could not restore fastfetch emblem: %v", err).withFix("ryoku materialize")
	}
	return fixedRes("restored the fastfetch emblem; the readout no longer falls back to the Arch logo")
}

// ---- reconciler: brand mark image --------------------------------------------

// brandMarkImage lifts the markImage override out of a brand.json body. false
// when the file does not parse, so a garbled brand leaves the reconciler
// nothing to defend (the JsonAdapter defaults, i.e. the 力 text seal, render).
func brandMarkImage(raw []byte) (string, bool) {
	var b struct {
		MarkImage string `json:"markImage"`
	}
	if err := json.Unmarshal(raw, &b); err != nil {
		return "", false
	}
	return b.MarkImage, true
}

// clearBrandImage blanks markImage in a brand.json body while preserving every
// other field (markText / markTint / name), so a dangling image override falls
// back to the text seal without dropping the user's name or tint pick.
func clearBrandImage(raw []byte) ([]byte, error) {
	var b map[string]any
	if err := json.Unmarshal(raw, &b); err != nil {
		return nil, err
	}
	b["markImage"] = ""
	out, err := json.MarshalIndent(b, "", "  ")
	if err != nil {
		return nil, err
	}
	return append(out, '\n'), nil
}

// expandBrandImage resolves a markImage the way the shell does before loading
// it: drop a file:// scheme, then expand a leading ~ to the home dir. an
// already-absolute path passes through, ready to stat.
func expandBrandImage(p string) string {
	return expandTilde(strings.TrimPrefix(p, "file://"))
}

// brandImageUsable: can the shell actually load this mark image? open (catches
// a missing or permission-locked file) and reject a directory, matching the
// only two ways QML's Image comes up empty on a set source.
func brandImageUsable(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	fi, err := f.Stat()
	return err == nil && !fi.IsDir()
}

// reconcileBrandLogo keeps the desktop brand off a broken image. brand.json's
// markImage override (Ryoku Settings -> Shell -> Global) wins over the 力 text
// seal everywhere in system chrome, but a moved, deleted, or unreadable image
// leaves every branded surface (pill, launcher, fastfetch, ...) with an empty
// mark: QML's Image renders nothing on a dangling source. clear the override so
// the mark falls back to the text seal, keeping the user's name and tint pick.
// no-op when brand.json is absent (text seal always renders), the file does not
// parse, markImage is empty, or the image resolves.
func reconcileBrandLogo(checkOnly bool) recResult {
	path := filepath.Join(sys.ConfigHome(), "ryoku", "brand.json")
	raw, err := os.ReadFile(path)
	if err != nil {
		return okRes("no brand override yet (seeded on first shell run)")
	}
	img, ok := brandMarkImage(raw)
	if !ok || img == "" {
		return okRes("brand mark uses the text seal")
	}
	resolved := expandBrandImage(img)
	if brandImageUsable(resolved) {
		return okRes("brand mark image resolves (%s)", resolved)
	}
	if checkOnly {
		return wouldRes("brand mark image missing or unreadable (%s); the mark renders empty", resolved).
			withFix("ryoku doctor clears it back to the text seal")
	}
	cleared, err := clearBrandImage(raw)
	if err != nil {
		return failRes("could not rewrite brand.json: %v", err).withFix("delete %s to re-seed it", path)
	}
	tmp := path + ".ryoku-tmp"
	if err := os.WriteFile(tmp, cleared, 0o644); err != nil {
		return failRes("could not write %s: %v", tmp, err)
	}
	if err := os.Rename(tmp, path); err != nil {
		os.Remove(tmp)
		return failRes("could not replace %s: %v", path, err)
	}
	return fixedRes("cleared the broken brand image (%s); the mark falls back to the text seal", img)
}

// ---- reconciler: retired follow-mouse default --------------------------------

// followMouseMarker records that the one-time follow-mouse heal has run, so a
// later deliberate "Normal" pick in Ryoku Settings is never quietly undone.
func followMouseMarker() string {
	return filepath.Join(sys.Xdg("XDG_STATE_HOME", ".local/state"), "ryoku", "migrations", "follow-mouse-default")
}

// hyprGetFollowMouse pulls input.followMouse out of a `ryoku-hub hypr get` JSON.
func hyprGetFollowMouse(raw string) (int, bool) {
	var o struct {
		Input struct {
			FollowMouse *int `json:"followMouse"`
		} `json:"input"`
	}
	if json.Unmarshal([]byte(raw), &o) != nil || o.Input.FollowMouse == nil {
		return 0, false
	}
	return *o.Input.FollowMouse, true
}

// hyprSetFollowMouse rewrites input.followMouse in a hypr-get JSON, preserving
// every other field, ready to hand straight back to `ryoku-hub hypr save`.
func hyprSetFollowMouse(raw string, v int) (string, error) {
	var o map[string]json.RawMessage
	if err := json.Unmarshal([]byte(raw), &o); err != nil {
		return "", err
	}
	var in map[string]json.RawMessage
	if err := json.Unmarshal(o["input"], &in); err != nil {
		return "", err
	}
	in["followMouse"] = json.RawMessage(strconv.Itoa(v))
	nb, err := json.Marshal(in)
	if err != nil {
		return "", err
	}
	o["input"] = nb
	b, err := json.Marshal(o)
	return string(b), err
}

// reconcileFollowMouseDefault: hypr.json files written before the follow-mouse
// default moved from 1 to 2 keep the old 1 baked in, so keyboard focus chases
// the cursor. Restore 2 once and drop a marker, so re-picking "Normal" (1) in
// Settings afterwards sticks.
func reconcileFollowMouseDefault(checkOnly bool) recResult {
	marker := followMouseMarker()
	if sys.Exists(marker) {
		return okRes("follow-mouse default already reconciled")
	}
	mark := func() {
		if checkOnly {
			return
		}
		_ = os.MkdirAll(filepath.Dir(marker), 0o755)
		_ = os.WriteFile(marker, []byte("done\n"), 0o644)
	}
	hyprJSON := filepath.Join(sys.ConfigHome(), "ryoku", "hypr.json")
	if !sys.Has("ryoku-hub") || !sys.Exists(hyprJSON) {
		mark() // nothing saved to migrate; the base module's follow_mouse = 2 stands.
		return okRes("no saved hypr input; follow-mouse uses the base default")
	}
	// check against the saved file directly: `ryoku-hub hypr get` rewrites the
	// hypr config as a side effect, which a --check/--report run must never do.
	fm, ok := hyprGetFollowMouse(readFileSafe(hyprJSON))
	if !ok || fm != 1 {
		mark()
		return okRes("follow-mouse is not on the retired default")
	}
	if checkOnly {
		return wouldRes("follow-mouse is pinned to the retired default 1; keyboard focus follows the cursor").
			withFix("ryoku doctor")
	}
	raw, err := sys.RunOut("ryoku-hub", "hypr", "get")
	if err != nil {
		return warnRes("could not read hypr settings to fix follow-mouse: %v", err)
	}
	fixed, err := hyprSetFollowMouse(raw, 2)
	if err != nil {
		return failRes("could not update hypr settings: %v", err)
	}
	if err := sys.Run("ryoku-hub", "hypr", "save", fixed); err != nil {
		return failRes("could not save the follow-mouse fix: %v", err).withFix("ryoku doctor")
	}
	mark()
	return fixedRes("restored follow-mouse to 2 (Loose); keyboard focus no longer follows the cursor")
}

// ---- reconciler: ryoku shell daemon ------------------------------------------

// reconcileShellDaemon: is the Ryoku shell control plane alive? the daemon
// (`ryoku-shell daemon`, autostarted by Hyprland) owns the Unix socket every
// keybind and quickshell component talks to -- if it dies, the whole shell
// is dead while the session target still looks up. Hyprland starts it once
// at login, so a crash leaves nothing to bring it back: that's what doctor
// is for. inside a live session it restarts the daemon; from a TTY or ssh
// there's no shell to manage, so it stays quiet.
func reconcileShellDaemon(checkOnly bool) recResult {
	if os.Getenv("HYPRLAND_INSTANCE_SIGNATURE") == "" {
		return okRes("not in a live Hyprland session")
	}
	if !sys.Has("ryoku-shell") {
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

// shellDaemonReachable dials the shell control socket and pings it: same
// round-trip the keybinds make. a stale socket from a crashed daemon refuses
// the connection; a hung daemon accepts but never replies, so the read is
// bounded.
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

// startShellDaemon launches `ryoku-shell daemon` detached from doctor: own
// session so it outlives this process, stdio to /dev/null. the daemon clears
// a stale socket and refuses to double-start, so this is only safe to call
// when the socket is already unreachable.
func startShellDaemon() error {
	cmd := exec.Command("ryoku-shell", "daemon")
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if devnull, err := os.OpenFile(os.DevNull, os.O_RDWR, 0); err == nil {
		cmd.Stdin, cmd.Stdout, cmd.Stderr = devnull, devnull, devnull
		defer devnull.Close()
	}
	return cmd.Start()
}

// waitDaemonReachable polls until the daemon answers or the deadline passes.
// it needs a moment to bind the socket and bootstrap.
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

// hyprDropin: a runtime-generated Hyprland Lua drop-in. hyprland.lua loads
// monitors.lua (ryoku-monitor) and gpu.lua (ryoku-gpu); both get rewritten
// while the session is live (a display hotplug or a GPU reset re-runs the
// generators), so a crash or a torn write can leave one unparseable. on the
// next Hyprland reload the whole config gets rejected and the compositor
// drops into on-screen emergency mode -- the "reload/doctor/update do
// nothing, only a reboot fixes it" failure -- until the file is repaired.
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

// reconcileHyprlandConfig keeps the Hyprland config loadable: the generic
// cure for the "desktop fell into emergency mode, only a reboot helped"
// report. checks the runtime-generated drop-ins still parse (a torn one
// would wedge the next reload), and in a live session asks Hyprland whether
// it's currently rejecting its config. corrupt drop-in -> regenerate from
// live state, else reset to a safe seed; in a live session, reload after, so
// the desktop leaves emergency mode right away instead of needing a reboot.
// hardware-agnostic: only ever validates and repairs config files.
func reconcileHyprlandConfig(checkOnly bool) recResult {
	dir := filepath.Join(sys.ConfigHome(), "hypr")
	if !sys.Exists(filepath.Join(dir, "hyprland.lua")) {
		return okRes("no Hyprland config present")
	}
	live := sys.HyprLive()

	if checkOnly {
		var broken []string
		for _, d := range hyprDropins() {
			p := filepath.Join(dir, d.name)
			if sys.Exists(p) && !hyprLuaParseable(p) {
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
		if !sys.Exists(p) || hyprLuaParseable(p) {
			continue
		}
		if repairHyprDropin(dir, d, live) {
			repaired = append(repaired, d.name)
		} else {
			failed = append(failed, d.name)
		}
	}

	// clean reload yanks a live session out of emergency mode right away.
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
			withFix("check ~/.config/hypr/user.lua or settings.lua")
	}
	return okRes("Hyprland config loads cleanly")
}

// reconcileThemeLua prunes an orphaned ~/.config/hypr/theme.lua. The Appearance
// Themes feature copied a rice's motion Lua there and hyprland.lua loaded it via
// optional("theme"); both are gone now, so the file no longer loads and lingers
// as dead state, only on a box that had a theme applied. Remove it so the config
// dir matches the shipped layout. Idempotent: ok when absent.
func reconcileThemeLua(checkOnly bool) recResult {
	p := filepath.Join(sys.ConfigHome(), "hypr", "theme.lua")
	if !sys.Exists(p) {
		return okRes("no orphaned theme.lua")
	}
	if checkOnly {
		return wouldRes("orphaned theme.lua from the retired Themes feature: %s", p).
			withFix("run `ryoku doctor` to remove it")
	}
	if err := os.Remove(p); err != nil {
		return failRes("could not remove orphaned theme.lua: %v", err).
			withFix("remove %s by hand", p)
	}
	return fixedRes("removed the orphaned theme.lua left by the retired Themes feature")
}

// reconcileDisplayModes recovers a monitor a degraded link left below its
// available resolution. after a cold boot or a post-upgrade `hyprctl reload`,
// a DP/HDMI link can briefly advertise only a VESA fallback (e.g. 800x600);
// Hyprland resolves monitors.lua's `highrr` against that list and never
// re-picks once the link trains, so the panel stays low-res until a relogin.
// `ryoku-monitor settle` re-asserts each output's intended mode (respecting
// an explicit Ryoku Settings pick and monitors_user.lua); `settle --check`
// is the read-only signal. live-only: no session = nothing to re-assert, the
// next login takes care of it.
func reconcileDisplayModes(checkOnly bool) recResult {
	if !sys.HyprLive() {
		return okRes("no live Hyprland session; displays settle at the next login")
	}
	if !sys.Has("ryoku-monitor") {
		return okRes("ryoku-monitor not installed")
	}
	if exec.Command("ryoku-monitor", "settle", "--check").Run() == nil {
		return okRes("every display is at its best available resolution")
	}
	if checkOnly {
		return wouldRes("a display is below its available resolution (the link came up degraded)").
			withFix("ryoku doctor (re-asserts each display's intended mode)")
	}
	if err := exec.Command("ryoku-monitor", "settle").Run(); err != nil {
		return warnRes("a display is below its available resolution and ryoku-monitor settle did not recover it").
			withFix("open Ryoku Settings > Displays and pick the resolution, or replug the cable")
	}
	return fixedRes("re-asserted a display that came up below its available resolution")
}

// repairHyprDropin rewrites a corrupt drop-in: regenerate from the live box
// if the generator is available, else fall back to the safe seed. both
// outcomes get re-validated, so even a generator that wrote garbage ends at
// a parseable file.
func repairHyprDropin(dir string, d hyprDropin, live bool) bool {
	p := filepath.Join(dir, d.name)
	if len(d.regen) > 0 && sys.Has(d.regen[0]) && (!d.needLive || live) {
		if exec.Command(d.regen[0], d.regen[1:]...).Run() == nil && hyprLuaParseable(p) {
			return true
		}
	}
	if os.WriteFile(p, []byte(d.seed), 0o644) != nil {
		return false
	}
	return hyprLuaParseable(p)
}

// hyprLuaParseable: will this Lua drop-in load? luac -p is definitive (the
// lua toolchain ships with Hyprland's config stack). without it, fall back
// to catching the truncation failure mode -- empty file or unbalanced
// brackets, which a whole generated drop-in (no brackets inside its string
// literals) never has. unreadable file is left alone, not clobbered.
func hyprLuaParseable(path string) bool {
	if sys.Has("luac") {
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

// liveConfigErrors returns Hyprland's current config errors (its
// emergency-mode reason), or "" when the config is clean or no live session
// is reachable.
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
	out, _ := sys.RunOut("systemctl", "--failed", "--no-legend", "--plain")
	for _, l := range nonEmptyLines(out) {
		if f := strings.Fields(l); len(f) > 0 {
			failed = append(failed, f[0])
		}
	}
	usr, _ := sys.RunOut("systemctl", "--user", "--failed", "--no-legend", "--plain")
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
	if !sys.IsBtrfs("/") {
		return okRes("root is not btrfs")
	}
	opts, _ := sys.RunOut("findmnt", "-n", "-o", "OPTIONS", "/")
	if first := strings.SplitN(strings.TrimSpace(opts), ",", 2); len(first) > 0 && first[0] == "ro" {
		return warnRes("root filesystem is mounted read-only (btrfs may be protecting itself)").
			withFix("check `btrfs filesystem usage /`; may need `btrfs balance` or more free space")
	}
	stats, err := sys.RunOut("sudo", "-n", "btrfs", "device", "stats", "/")
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
	out, _ := sys.RunOut("find", "/etc", "-name", "*.pacnew")
	files := nonEmptyLines(out)
	if len(files) == 0 {
		return okRes("no pending config updates")
	}
	return warnRes("%d pending config update(s) (.pacnew)", len(files)).
		withFix("review and merge with `sudo pacdiff` (from pacman-contrib)")
}

// ---- reconciler: orphaned packages -------------------------------------------

func reconcileOrphans(_ bool) recResult {
	out, err := sys.RunOut("pacman", "-Qtdq")
	orphans := nonEmptyLines(out)
	if err != nil || len(orphans) == 0 {
		return okRes("no orphaned packages")
	}
	return noteRes("%d orphaned package(s)", len(orphans)).
		withFix("review `pacman -Qtd`, then `sudo pacman -Rns $(pacman -Qtdq)` if unneeded")
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

// parseProcSwaps: file-backed swaps from /proc/swaps content. first line is
// a header; the path field escapes spaces as \040.
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

func dirOnlyContains(dir, name string) bool {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return false
	}
	return len(entries) == 1 && entries[0].Name() == name
}

// relocateSwapToSubvolume: swapoff the file, turn its dir into a btrfs
// subvolume, recreate the swapfile inside at the same path + size, swap it
// back on. path is unchanged, so the fstab swap entry still resolves and
// the nested subvolume comes up with its parent -- no fstab edit.
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
		if err := sys.Run("sudo", s...); err != nil {
			return fmt.Errorf("%s: %w", strings.Join(s, " "), err)
		}
	}
	return nil
}

// ---- small shared helpers ----------------------------------------------------

func firstLine(s string) string {
	if i := strings.IndexByte(s, '\n'); i >= 0 {
		return strings.TrimSpace(s[:i])
	}
	return strings.TrimSpace(s)
}

func anyPkgInstalled(names ...string) bool {
	for _, n := range names {
		if sys.PkgInstalled(n) {
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

// captureOut runs a command and returns combined output (or the error text):
// best-effort diagnostics where a non-zero exit is still informative.
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
