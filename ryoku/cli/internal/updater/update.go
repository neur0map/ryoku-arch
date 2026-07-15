package updater

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"ryoku-cli/internal/sys"
	"strings"
	"syscall"
	"time"
)

const snapperConfig = "root"

// gitSteps / pkgSteps are the ordered stages the GUI renders as a determinate
// multi-segment bar. The git-channel path (a dev/mirror checkout) and the
// packaged path (pacman) run different stages; stage2 re-begins pkgSteps and
// marks the pre-handoff steps done so the exec handoff keeps one continuous bar.
var (
	gitSteps = []runStep{
		{Key: "snapshot", Label: "Taking a snapshot"},
		{Key: "channel", Label: "Pulling the latest commits"},
		{Key: "deploy", Label: "Deploying the desktop"},
		{Key: "doctor", Label: "Healing the system"},
		{Key: "finalize", Label: "Finishing up"},
	}
	pkgSteps = []runStep{
		{Key: "snapshot", Label: "Taking a snapshot"},
		{Key: "packages", Label: "Updating packages"},
		{Key: "aur", Label: "Updating AUR packages"},
		{Key: "apply", Label: "Applying the new configuration"},
		{Key: "reload", Label: "Reloading the desktop"},
		{Key: "doctor", Label: "Healing the system"},
		{Key: "finalize", Label: "Finishing up"},
	}
)

// Update = the whole safe update, wrapped in a snapper pre/post pair.
// checkout box -> git channel (fast-forward + redeploy). packaged box ->
// pacman, then hand off to the binary pacman just installed (--stage2) so the
// deploy and doctor semantics of the new release apply during this same
// update, not one release late. stage2 quiesces the shell, materializes,
// brings the desktop back, and runs `ryoku doctor` (same one users run by
// hand) to heal stateful drift, then the post snapshot. snapshots are
// best-effort: an unconfigured snapper never blocks an update, but a failed
// step still aborts first. Each stage is published to the run-state file so
// the update island and Hub show real, determinate progress.
func Update(args []string) error {
	if len(args) >= 2 && args[0] == "--stage2" {
		return updateStage2(args[1])
	}

	checkout := sys.ResolveRepo() != ""
	if checkout {
		progress.begin(gitSteps)
	} else {
		progress.begin(pkgSteps)
	}

	progress.at("snapshot")
	pre := snapperPre("ryoku-update")
	progress.setSnapshot(pre)

	// checkout: update through the git channel. packaged: pacman + a hand-off
	// to the freshly installed binary (stage2).
	if checkout {
		if err := channelUpdate(); err != nil {
			progress.fail(err)
			return err
		}
		rashinReindex()
		progress.at("doctor")
		offerSnapperHelpers()
		runFreshDoctor()
		progress.at("finalize")
		snapperPost(pre, "ryoku-update")
		progress.logf("Update complete")
		return finishRun()
	}

	progress.at("packages")
	progress.logf("Updating system packages (pacman)")
	clearStalePacmanLock()
	if err := sys.Sudo("pacman", "-Syu", "--noconfirm"); err != nil {
		// only advertise `ryoku rollback` when the pre snapshot it needs exists;
		// snapperPre is best-effort and returns "" when it was skipped.
		hint := "no pre-update snapshot exists (snapper was unavailable), so `ryoku rollback` cannot revert this; recover with pacman directly"
		if pre != "" {
			hint = "see `ryoku rollback` (pre-update snapshot " + pre + ")"
		}
		e := fmt.Errorf("pacman -Syu failed; %s: %w", hint, err)
		progress.fail(e)
		return e
	}

	if sys.Has("yay") {
		progress.at("aur")
		progress.logf("Updating AUR packages (yay)")
		if err := sys.Run("yay", "-Sua", "--noconfirm"); err != nil {
			fmt.Fprintf(os.Stderr, "warning: yay update reported errors: %v\n", err)
		}
	} else {
		progress.skip("aur")
	}

	// exec replaces this process with the freshly installed binary; on any
	// failure fall through and finish in-process, exactly as before.
	if sys.Exists("/usr/bin/ryoku") {
		if err := syscall.Exec("/usr/bin/ryoku", []string{"ryoku", "update", "--stage2", pre}, os.Environ()); err != nil {
			fmt.Fprintf(os.Stderr, "warning: could not hand off to the updated binary: %v\n", err)
		}
	}
	return updateStage2(pre)
}

// finishRun publishes the terminal "done" state, holds it briefly so a watching
// GUI catches the completion, then clears the run so the island folds away.
func finishRun() error {
	progress.finish()
	time.Sleep(1200 * time.Millisecond)
	progress.idle()
	return nil
}

// updateStage2 finishes an update after the package transactions: deploy the
// new configs with the shell quiesced, bring the desktop back, heal drift. It
// runs in the freshly installed binary (a new process after the exec handoff),
// so it re-begins the packaged step list and marks the pre-handoff steps done
// to keep one continuous progress bar.
func updateStage2(pre string) error {
	progress.begin(pkgSteps)
	progress.setSnapshot(pre)
	progress.markDone("snapshot", "packages")
	if sys.Has("yay") {
		progress.markDone("aur")
	} else {
		progress.skip("aur")
	}

	progress.at("apply")
	progress.logf("Applying the new configuration")
	// stop the shell first: a live quickshell would hot-reload the half-copied
	// tree mid-swap, re-instantiating the new QML against whatever plugin .so
	// the old process still has mapped. pause Hyprland's Lua auto-reload for
	// the same reason (= emergency overlay popping up with no keybinds).
	stopShell()
	hyprPauseAutoreload()
	if err := Materialize(); err != nil {
		hyprReload()
		startShell()
		progress.fail(err)
		return err
	}

	progress.at("reload")
	progress.logf("Reloading the desktop")
	// one clean reload picks up the new config and restores auto-reload, then
	// start the shell daemon so the new binary + QML both take effect.
	hyprReload()
	startShell()
	rashinReindex()

	progress.at("doctor")
	offerSnapperHelpers()
	runFreshDoctor()

	progress.at("finalize")
	snapperPost(pre, "ryoku-update")
	progress.logf("Update complete")
	return finishRun()
}

// rashinReindex refreshes the agent-OS vault after an update so agents see
// the new system immediately. Best effort: rashin is optional and a failed
// index never blocks an update.
func rashinReindex() {
	if !sys.Has("ryoku-rashin") {
		return
	}
	fmt.Println("==> Reindexing the Rashin vault")
	if err := sys.Run(pkgBin("ryoku-rashin"), "index"); err != nil {
		fmt.Fprintf(os.Stderr, "warning: rashin reindex failed: %v\n", err)
	}
}

// clearStalePacmanLock mirrors doctor's reconcilePacmanLock right before the
// system upgrade: a db.lck left by a crashed pacman would fail the very update
// the user is running to heal the box. A lock owned by a live pacman is left
// alone. Composed from sys primitives, same reason as snapHelpers below.
func clearStalePacmanLock() {
	const lock = "/var/lib/pacman/db.lck"
	if !sys.Exists(lock) {
		return
	}
	if exec.Command("pgrep", "-x", "pacman").Run() == nil {
		return
	}
	progress.logf("Removing a stale pacman lock (no pacman running)")
	_ = sys.Sudo("rm", "-f", lock)
}

// snapHelpers: the snapshot facts the offer gates on, composed from sys
// primitives so the updater runs the same checks the doctor does without
// importing the doctor package.
type snapHelpers struct {
	rootBtrfs  bool
	snapper    bool
	snapPac    bool
	limineSync bool
	limine     bool
}

func gatherSnapHelpers() snapHelpers {
	return snapHelpers{
		rootBtrfs:  sys.IsBtrfs("/"),
		snapper:    sys.Has("snapper"),
		snapPac:    sys.PkgInstalled("snap-pac"),
		limineSync: sys.PkgInstalled("limine-snapper-sync"),
		limine:     sys.PkgInstalled("limine"),
	}
}

// wantedSnapperHelpers: which snapshot helpers to offer, given the facts. pure,
// so the gating (no snapshots without btrfs + snapper; limine-snapper-sync only
// under Limine) is unit-testable without touching /etc or pacman.
func wantedSnapperHelpers(h snapHelpers) []string {
	if !h.rootBtrfs || !h.snapper {
		return nil
	}
	var want []string
	if !h.snapPac {
		want = append(want, "snap-pac")
	}
	if !h.limineSync && h.limine {
		want = append(want, "limine-snapper-sync")
	}
	return want
}

// offerSnapperHelpers: ask before installing the missing helpers, then
// install whoever was picked. snap-pac = a snapshot on every pacman txn;
// limine-snapper-sync, on a Limine box, puts those snapshots in the boot
// menu. together = the rollback safety net behind every `ryoku update`.
// opt-in + best-effort: Skip (or no answer) leaves them for `ryoku doctor`
// to keep recommending, and a failed install never aborts the update.
func offerSnapperHelpers() {
	want := wantedSnapperHelpers(gatherSnapHelpers())
	if len(want) == 0 {
		return
	}
	var blurbs []string
	for _, p := range want {
		switch p {
		case "snap-pac":
			blurbs = append(blurbs, "auto-snapshot every update")
		case "limine-snapper-sync":
			blurbs = append(blurbs, "snapshots in the boot menu")
		}
	}
	detail := strings.Join(want, " + ") + " back the rollback safety net (" + strings.Join(blurbs, ", ") + ")."
	if !askInstall("Enable snapshot helpers?", detail, want) {
		fmt.Printf("==> Snapshot helpers skipped (%s); ryoku doctor keeps recommending them\n", strings.Join(want, ", "))
		return
	}
	fmt.Printf("==> Installing snapshot helpers: %s\n", strings.Join(want, ", "))
	for _, p := range want {
		tool := "ryoku-pkg-add"
		if p == "limine-snapper-sync" {
			tool = "ryoku-pkg-aur-add"
		}
		if err := sys.Run(tool, p); err != nil {
			fmt.Fprintf(os.Stderr, "warning: installing %s failed: %v\n", p, err)
		}
	}
}

// askInstall: consent for installing pkgs. hub-launched update
// (RYOKU_UPDATE_UI=hub) -> ask through the run-state prompt and wait.
// plain terminal -> y/N. non-interactive -> decline.
func askInstall(title, detail string, pkgs []string) bool {
	if os.Getenv("RYOKU_UPDATE_UI") == "hub" {
		publishPrompt("snapper-helpers", title, detail, []string{"Install", "Skip"})
		choice, ok := awaitAnswer(120 * time.Second)
		progress.publish("running") // clear the prompt; resume the step view
		return ok && choice == "Install"
	}
	if sys.StdinIsTTY() {
		fmt.Printf("%s install %s? [y/N] ", title, strings.Join(pkgs, ", "))
		var resp string
		_, _ = fmt.Scanln(&resp)
		resp = strings.ToLower(strings.TrimSpace(resp))
		return resp == "y" || resp == "yes"
	}
	return false
}

// runFreshDoctor runs `ryoku doctor` after the new binary lands, so the
// reconcilers shipped in this release run inside the same update. same
// command users run by hand; calling it here keeps doctor one thing instead
// of a copy baked into update. best-effort: a finding never fails update.
func runFreshDoctor() {
	fmt.Println("==> Running doctor")
	// pkgBin, not PATH: on a box with ~/.local/bin residue the bare name is the
	// STALE CLI, whose doctor predates the reconcilers this release ships --
	// including the residue scan that would clear that very shadow.
	_ = sys.Run(pkgBin("ryoku"), "doctor")
}

// Rollback guides restoring a snapshot. Ryoku pins the root subvolume on the
// kernel cmdline and in fstab (rootflags=subvol=@), and `snapper rollback`
// cannot serve that layout: it works by flipping the btrfs default subvolume,
// which a pinned subvol= simply ignores -- limine-snapper-sync's own tooling
// states the layout is "not compatible with 'snapper rollback'". The supported
// restore is the boot menu: boot the snapshot entry (whose matching kernels
// limine-snapper-sync staged on the ESP), then `limine-snapper-restore` copies
// it back onto @. So this command teaches that flow instead of running a
// snapper command that cannot restore the system.
func Rollback(args []string) error {
	id := "<id>"
	if len(args) == 0 {
		fmt.Println("Snapshots (pick an id, or choose one under Snapshots in the Limine boot menu):")
		if err := Snapshots(); err != nil {
			return err
		}
		fmt.Println()
	} else {
		id = args[0]
		fmt.Printf("==> Restoring snapshot %s\n\n", id)
	}
	fmt.Println("Ryoku boots the @ subvolume directly, so a live `snapper rollback` cannot")
	fmt.Println("restore the system; the restore runs from the boot menu instead:")
	fmt.Printf("  1. Reboot, and in the Limine menu open Snapshots -> snapshot %s.\n", id)
	fmt.Println("  2. Boot it, then run `sudo limine-snapper-restore` in a terminal (it offers")
	fmt.Println("     to restore the snapshot you are booted into, matching kernels included).")
	fmt.Println("  3. Reboot back into the restored system.")
	if !sys.PkgInstalled("limine-snapper-sync") {
		fmt.Println()
		fmt.Println("limine-snapper-sync is not installed, so snapshots are missing from the boot")
		fmt.Println("menu. Install it first:")
		fmt.Println("  ryoku-pkg-aur-add limine-snapper-sync && sudo systemctl enable --now limine-snapper-sync.service")
	}
	return nil
}

func Snapshots() error {
	if !sys.Has("snapper") {
		return fmt.Errorf("snapper is not installed")
	}
	return sys.Sudo("snapper", "-c", snapperConfig, "list")
}

func Status(args []string) error {
	jsonOut := false
	for _, a := range args {
		if a == "--json" {
			jsonOut = true
		}
	}
	r := buildStatus()

	if jsonOut {
		b, _ := json.Marshal(r)
		fmt.Println(string(b))
		return nil
	}

	fmt.Printf("config base:   %s\n", sys.BaseConfigDir())
	fmt.Printf("channel:       %s\n", orDash(r.Channel))
	fmt.Printf("installed:     %s\n", orDash(r.Installed))
	if r.Available {
		fmt.Printf("available:     %s\n", orDash(r.Latest))
		fmt.Printf("behind:        %d commit(s)\n", r.Behind)
	} else {
		fmt.Println("behind:        up to date")
	}
	// a bare 0 can't tell "configured but empty" from "snapper has no root
	// config at all". doctor restores a missing config, so send the user
	// there rather than letting status look healthy on a broken setup.
	if sys.Exists("/etc/snapper/configs/root") {
		fmt.Printf("snapshots:     %d\n", r.Snapshots)
	} else {
		fmt.Println("snapshots:     not configured (run ryoku doctor)")
	}
	return nil
}

// statusReport = what the Hub and the update island read from
// `ryoku status --json`. installed + available versions, how far behind,
// per-item list. from the git update channel on a Ryoku checkout (the live
// mirror), else from the [ryoku] pacman repo.
type statusReport struct {
	Installed string       `json:"installedVersion"`
	Latest    string       `json:"latestVersion"`
	Available bool         `json:"available"`
	Behind    int          `json:"pendingUpdates"`
	Updates   []updateItem `json:"updates"`
	Channel   string       `json:"channel"`
	Snapshots int          `json:"snapshots"`
}

// buildStatus prefers the git update channel (a checkout tracking main). No
// checkout (a packaged install) -> read the running and available commits from
// the [ryoku] repo's package versions and list what is incoming between them via
// the public GitHub compare API, so the Hub's Updates list is the same commit
// subjects a dev box shows, not bare package names.
func buildStatus() statusReport {
	if r, ok := channelStatus(); ok {
		return r
	}
	installed := sys.InstalledVersion()
	latest := latestAvailable("ryoku-desktop")
	for _, u := range pendingUpdates() {
		if u.Name == "ryoku-desktop" {
			latest = u.New
		}
	}
	installedSha := shortCommit(installed)
	latestSha := shortCommit(latest)

	r := statusReport{
		Installed: installedSha,
		Latest:    latestSha,
		Updates:   []updateItem{}, // non-nil, so a current box marshals [] like the git path
		Channel:   ryokuChannel(),
		Snapshots: snapshotCount(),
	}
	// current, or the [ryoku] repo isn't synced yet: nothing incoming.
	if installedSha == "" || latestSha == "" || installedSha == latestSha {
		return r
	}
	r.Available = true
	if ups, behind := incomingCommits(installedSha, latestSha); len(ups) > 0 {
		r.Updates = ups
		r.Behind = behind
	} else {
		// compare unreachable (offline / rate-limited): still surface the
		// pending Ryoku bump so the section isn't empty and available holds.
		r.Updates = []updateItem{{Name: "ryoku-desktop", Old: installed, New: latest}}
		r.Behind = 1
	}
	return r
}

// shortCommit pulls the abbreviated commit hash out of a packaged version
// shaped <core>.r<count>.g<sha>(-pkgrel) (what the repo build embeds), so
// Hub and CLI can show the exact commit a packaged box runs. no gNNNN token
// (a hand-pinned 0.1.0-3, say) -> input comes back unchanged.
func shortCommit(ver string) string {
	for _, tok := range strings.FieldsFunc(ver, func(r rune) bool { return r == '.' || r == '-' }) {
		if len(tok) >= 8 && tok[0] == 'g' && isHex(tok[1:]) {
			return tok[1:]
		}
	}
	return ver
}

func isHex(s string) bool {
	for _, c := range s {
		if (c < '0' || c > '9') && (c < 'a' || c > 'f') && (c < 'A' || c > 'F') {
			return false
		}
	}
	return s != ""
}

// latestAvailable: version of pkg in the [ryoku] repo, or "" when the repo
// isn't synced/configured. `pacman -Sl ryoku` = "<repo> <pkg> <ver>".
func latestAvailable(pkg string) string {
	out, err := sys.RunOut("pacman", "-Sl", "ryoku")
	if err != nil {
		return ""
	}
	sc := bufio.NewScanner(strings.NewReader(out))
	for sc.Scan() {
		f := strings.Fields(sc.Text())
		if len(f) >= 3 && f[1] == pkg {
			return f[2]
		}
	}
	return ""
}

// updateItem = one row in the update list. pacman -> a package (name,
// old -> new). git channel -> a commit (subject in Name, short hash in New).
type updateItem struct {
	Name string `json:"name"`
	Old  string `json:"old"`
	New  string `json:"new"`
}

// pendingUpdates: packages with a newer version available, via checkupdates
// (pacman-contrib). syncs to a private db, so no root needed. empty when
// the system is current or checkupdates is absent.
func pendingUpdates() []updateItem {
	ups := []updateItem{}
	if !sys.Has("checkupdates") {
		return ups
	}
	// cap the check: checkupdates syncs package dbs over the network and the
	// update island polls this, so it MUST never hang status. generous so a
	// slow sync still finishes.
	ctx, cancel := context.WithTimeout(context.Background(), 120*time.Second)
	defer cancel()
	out, _ := exec.CommandContext(ctx, "checkupdates").Output()
	sc := bufio.NewScanner(strings.NewReader(string(out)))
	for sc.Scan() {
		f := strings.Fields(sc.Text())
		if len(f) >= 4 && f[2] == "->" {
			ups = append(ups, updateItem{Name: f[0], Old: f[1], New: f[3]})
		}
	}
	return ups
}

func snapshotCount() int {
	if !sys.Has("snapper") {
		return 0
	}
	// `ryoku status` is polled from the GUI (Hub + pill) on a timer, no
	// controlling terminal. snapper wants root; interactive sudo with no tty
	// can't read a password, the PAM conversation fails, pam_faillock counts
	// each failure, and the account ends up locked out of sudo even with the
	// correct password. (yes, found this one the loud way.) so a read-only
	// status query MUST never escalate: skip the count unless a real terminal
	// drives us, and even then never prompt (sudo -n = already-cached cred only).
	if !sys.StdinIsTTY() {
		return 0
	}
	out, err := sys.RunOut("sudo", "-n", "snapper", "-c", snapperConfig, "list")
	if err != nil {
		return 0
	}
	if n := sys.CountNonEmpty(out) - 2; n > 0 {
		return n
	}
	return 0
}

func orDash(s string) string {
	if s == "" {
		return "-"
	}
	return s
}

// Deploy = the DEV loop: build the Go binaries + plugin and materialize
// from a repo checkout. production installs never see this; they pull
// everything from the [ryoku] pacman repo.
func Deploy(_ []string) error {
	repo := os.Getenv("RYOKU_REPO")
	if repo == "" {
		return fmt.Errorf("set RYOKU_REPO to a Ryoku checkout for `ryoku deploy`")
	}
	script := filepath.Join(repo, "ryoku", "shell", "deploy.sh")
	if !sys.Exists(script) {
		return fmt.Errorf("not a Ryoku checkout (missing %s)", script)
	}
	return sys.Run(script)
}

// --- snapper pre/post (best-effort) ----------------------------------------

func snapperPre(desc string) string {
	if !sys.Has("snapper") {
		fmt.Fprintln(os.Stderr, "note: snapper not installed; skipping pre-update snapshot")
		return ""
	}
	// no root config -> the create below fails with an opaque
	// "config 'root' does not exist". point the user at the fix.
	if !sys.Exists("/etc/snapper/configs/root") {
		fmt.Fprintln(os.Stderr, "note: snapshot skipped, snapper root config missing; run 'ryoku doctor' to enable snapshots")
		return ""
	}
	out, err := sys.RunOut("sudo", "snapper", "-c", snapperConfig, "create",
		"-t", "pre", "-c", "number", "-p", "-d", desc)
	if err != nil {
		fmt.Fprintf(os.Stderr, "note: pre-update snapshot skipped: %v\n", err)
		return ""
	}
	return strings.TrimSpace(out)
}

func snapperPost(pre, desc string) {
	if pre == "" {
		return
	}
	_ = sys.Sudo("snapper", "-c", snapperConfig, "create",
		"-t", "post", "--pre-number", pre, "-c", "number", "-d", desc)
}

// hyprPauseAutoreload stops Hyprland reloading the Lua config mid-swap, so a
// half-written file is never observed (would trip the emergency overlay).
func hyprPauseAutoreload() {
	if sys.HyprLive() {
		_ = exec.Command("hyprctl", "keyword", "misc:disable_autoreload", "true").Run()
	}
}

// hyprReload applies the materialized config in one clean pass. the reload
// also restores auto-reload, since keywords reset from the config.
func hyprReload() {
	if sys.HyprLive() {
		_ = exec.Command("hyprctl", "reload").Run()
	}
}

// pkgBin resolves a Ryoku binary an update drives. The packaged /usr/bin copy
// is preferred over a bare PATH lookup: a past `ryoku recovery` or dev deploy
// leaves builds in ~/.local/bin that outrank /usr/bin, and driving those runs
// stale code inside the very update meant to supersede it -- a stale daemon
// restarted over the new QML replays an old supervisor against a one-shot
// switcher (the beta-17 switcher-reopen loop), and a stale doctor predates the
// reconcilers this release ships. A box without the package (a pure checkout)
// falls back to PATH, where the just-deployed build is the right one.
func pkgBin(name string) string {
	if p := "/usr/bin/" + name; sys.Exists(p) {
		return p
	}
	return name
}

// stopShell quiesces the desktop for a config swap: ask the daemon to quit,
// wait for it to go, then drop orphaned surfaces still holding a config's
// single-instance lock (one survivor kills the fresh daemon's components).
// The component list mirrors shell/ipc/daemon.go; "plugins" and "wallpaper"
// are retired resident components, still reaped on boxes whose live daemon
// predates their removal.
func stopShell() {
	if !sys.Has("ryoku-shell") {
		return
	}
	shell := pkgBin("ryoku-shell")
	_ = exec.Command(shell, "quit").Run()
	for i := 0; i < 20; i++ {
		if exec.Command(shell, "ping").Run() != nil {
			break
		}
		time.Sleep(100 * time.Millisecond)
	}
	// the pattern is anchored: quickshell is a general-purpose tool, and a bare
	// "qs -c wallpaper" would also match a user's own longer config name
	// ("qs -c wallpaperclock"). the daemon always spawns the config name as the
	// final argv element.
	for _, c := range []string{"pill", "launcher", "visualizer", "widgets", "overview", "plugins", "wallpaper"} {
		_ = exec.Command("pkill", "-f", "qs -c "+c+"($| )").Run()
	}
	// The video players outlive the daemon (spawned detached): kill the
	// current one so the restarted daemon relaunches it on the new binary, and
	// the legacy backends older releases shipped (mpvpaper, phonto) -- the new
	// daemon no longer knows their names, and an orphan left on the background
	// layer stacks above awww and swallows every static set after the update.
	for _, p := range []string{"ryoku-livewall", "mpvpaper", "phonto"} {
		_ = exec.Command("pkill", "-x", p).Run()
	}
	time.Sleep(200 * time.Millisecond)
}

// startShell brings the shell daemon up on the current binary, detached so it
// outlives this process. mirrors deploy.sh.
func startShell() {
	if !sys.Has("ryoku-shell") {
		return
	}
	cmd := exec.Command("setsid", pkgBin("ryoku-shell"), "daemon")
	logp := filepath.Join(sys.Xdg("XDG_STATE_HOME", ".local/state"), "ryoku-shell.log")
	_ = os.MkdirAll(filepath.Dir(logp), 0o755)
	if f, err := os.OpenFile(logp, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644); err == nil {
		cmd.Stdout, cmd.Stderr = f, f
	}
	_ = cmd.Start()
}

func materializeStatePath() string {
	return filepath.Join(sys.Xdg("XDG_STATE_HOME", ".local/state"), "ryoku", "materialized")
}
