// ryoku = the user-facing CLI for the distro. one front door to updates,
// rollback, and the shell. orchestrates pacman / yay / snapper / materialize;
// doesn't reimplement any of them.
//
//	ryoku update            snapshot -> channel pull or pacman -Syu -> deploy -> reload
//	ryoku rollback [id]     restore a snapper snapshot (or list them)
//	ryoku snapshots         list snapper snapshots
//	ryoku status            version, commits behind the channel, snapshot count
//	ryoku materialize       lay the base configs into ~/.config (override-safe)
//	ryoku reload            restart the shell + reload Hyprland
//	ryoku deploy            DEV ONLY: build + materialize from a checkout
//	ryoku recovery          last resort: reset to main + redeploy (overwrites configs)
//	ryoku doctor            run convergent reconcilers (also runs inside update)
package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

const snapperConfig = "root"

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(2)
	}
	var err error
	switch os.Args[1] {
	case "update":
		err = cmdUpdate(os.Args[2:])
	case "materialize":
		err = materialize()
	case "rollback":
		err = cmdRollback(os.Args[2:])
	case "snapshots":
		err = cmdSnapshots()
	case "status":
		err = cmdStatus(os.Args[2:])
	case "version", "--version", "-v":
		err = cmdVersion(os.Args[2:])
	case "reload":
		err = run("ryoku-shell", "reload")
	case "deploy":
		err = cmdDeploy(os.Args[2:])
	case "recovery":
		err = cmdRecovery(os.Args[2:])
	case "doctor":
		err = cmdDoctor(os.Args[2:])
	case "-h", "--help", "help", "":
		usage()
	default:
		die("unknown command: %s", os.Args[1])
	}
	if err != nil {
		die("%v", err)
	}
}

func usage() {
	fmt.Print(`Usage: ryoku <command>

  update         apply channel commits (or pacman -Syu), redeploy, reload
  rollback [id]  restore a snapper snapshot (no id: list them)
  snapshots      list snapper snapshots
  status         version, commits behind the channel, snapshot count
  version        print the running version (--branch = channel · sha)
  materialize    lay the base configs into ~/.config (keeps your overrides)
  reload         restart the shell and reload Hyprland
  deploy         DEV ONLY: deploy from a repo checkout (RYOKU_REPO)
  recovery       last resort: reset to main and redeploy (overwrites configs)
  doctor         run convergent reconcilers (idempotent stateful fixes)
`)
}

// cmdUpdate = the whole safe update, wrapped in a snapper pre/post pair.
// checkout box -> git channel (fast-forward + redeploy). packaged box ->
// pacman + materialize + reload. once the new binary is in place we call
// `ryoku doctor` (same one users run by hand) to heal stateful drift, then
// the post snapshot. snapshots are best-effort: an unconfigured snapper
// never blocks an update, but a failed step still aborts first.
func cmdUpdate(_ []string) error {
	pre := snapperPre("ryoku-update")
	publishRun("running", 0.05)
	defer publishRun("idle", 0)

	// checkout: update through the git channel. packaged: pacman.
	// channelUpdate handles the former and reports whether it ran; if not,
	// fall through to the package transactions.
	if handled, err := channelUpdate(); err != nil {
		return err
	} else if handled {
		rashinReindex()
		offerSnapperHelpers()
		runFreshDoctor()
		snapperPost(pre, "ryoku-update")
		fmt.Println("==> Update complete")
		return nil
	}

	fmt.Println("==> Updating system packages (pacman)")
	if err := sudo("pacman", "-Syu", "--noconfirm"); err != nil {
		return fmt.Errorf("pacman -Syu failed; system unchanged from this point, see `ryoku rollback`: %w", err)
	}
	publishRun("running", 0.5)

	if has("yay") {
		fmt.Println("==> Updating AUR packages (yay)")
		if err := run("yay", "-Sua", "--noconfirm"); err != nil {
			fmt.Fprintf(os.Stderr, "warning: yay update reported errors: %v\n", err)
		}
	}
	publishRun("running", 0.7)

	fmt.Println("==> Materializing desktop configs")
	// pause Hyprland's Lua auto-reload so the swap isn't observed mid-write
	// (= emergency overlay popping up with no keybinds).
	hyprPauseAutoreload()
	if err := materialize(); err != nil {
		hyprReload()
		return err
	}
	publishRun("running", 0.9)

	fmt.Println("==> Reloading desktop")
	// one clean reload picks up the new config and restores auto-reload, then
	// restart the shell daemon so the new binary + QML both take effect.
	hyprReload()
	restartShell()
	rashinReindex()

	offerSnapperHelpers()
	runFreshDoctor()
	snapperPost(pre, "ryoku-update")
	fmt.Println("==> Update complete")
	return nil
}

// rashinReindex refreshes the agent-OS vault after an update so agents see
// the new system immediately. Best effort: rashin is optional and a failed
// index never blocks an update.
func rashinReindex() {
	if !has("ryoku-rashin") {
		return
	}
	fmt.Println("==> Reindexing the Rashin vault")
	if err := run("ryoku-rashin", "index"); err != nil {
		fmt.Fprintf(os.Stderr, "warning: rashin reindex failed: %v\n", err)
	}
}

// wantedSnapperHelpers: which snapshot helpers we should offer to install,
// given snapper state + whether Limine is the bootloader. pure, so the
// gating (no snapshots without btrfs + snapper; limine-snapper-sync only
// under Limine) is unit-testable without touching /etc or pacman.
func wantedSnapperHelpers(st snapperState, limineInstalled bool) []string {
	if !st.rootIsBtrfs || !st.snapperInstalled {
		return nil
	}
	var want []string
	if !st.snapPacInstalled {
		want = append(want, "snap-pac")
	}
	if !st.limineSyncInstalled && limineInstalled {
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
	want := wantedSnapperHelpers(gatherSnapperState(), pkgInstalled("limine"))
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
		if err := run(tool, p); err != nil {
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
		publishRun("running", 0.75) // clear the prompt; resume the progress wave
		return ok && choice == "Install"
	}
	if stdinIsTTY() {
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
	_ = run("ryoku", "doctor")
}

func cmdRollback(args []string) error {
	if len(args) == 0 {
		fmt.Println("Pick a snapshot id and run `ryoku rollback <id>` (or choose it from the Limine boot menu):")
		return cmdSnapshots()
	}
	id := args[0]
	fmt.Printf("==> Rolling back to snapshot %s\n", id)
	return sudo("snapper", "-c", snapperConfig, "rollback", id)
}

func cmdSnapshots() error {
	if !has("snapper") {
		return fmt.Errorf("snapper is not installed")
	}
	return sudo("snapper", "-c", snapperConfig, "list")
}

func cmdStatus(args []string) error {
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

	fmt.Printf("config base:   %s\n", baseConfigDir())
	if r.Git {
		fmt.Printf("channel:       %s\n", r.Channel)
		fmt.Printf("installed:     %s\n", orDash(r.Installed))
		if r.Available {
			fmt.Printf("available:     %s\n", orDash(r.Latest))
			fmt.Printf("behind:        %d commit(s)\n", r.Behind)
		} else {
			fmt.Println("behind:        up to date")
		}
	} else {
		fmt.Printf("channel:       %s\n", orDash(r.Channel))
		fmt.Printf("installed:     %s\n", orDash(r.Installed))
		if r.Available {
			fmt.Printf("available:     %s\n", orDash(r.Latest))
		}
		if has("checkupdates") {
			fmt.Printf("pending:       %d package update(s)\n", r.Behind)
		} else {
			fmt.Println("pending:       (install pacman-contrib for checkupdates)")
		}
	}
	// a bare 0 can't tell "configured but empty" from "snapper has no root
	// config at all". doctor restores a missing config, so send the user
	// there rather than letting status look healthy on a broken setup.
	if exists("/etc/snapper/configs/root") {
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
	Git       bool         `json:"-"`
}

// buildStatus prefers the git update channel (a checkout tracking main).
// no checkout -> fall back to the pacman view of the [ryoku] repo.
func buildStatus() statusReport {
	if r, ok := channelStatus(); ok {
		return r
	}
	installed := installedVersion()
	latest := latestAvailable("ryoku-desktop")
	ups := pendingUpdates()
	for _, u := range ups {
		if u.Name == "ryoku-desktop" {
			latest = u.New
		}
	}
	return statusReport{
		Installed: shortCommit(installed),
		Latest:    shortCommit(latest),
		Available: len(ups) > 0,
		Behind:    len(ups),
		Updates:   ups,
		Channel:   ryokuChannel(),
		Snapshots: snapshotCount(),
	}
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
	out, err := runOut("pacman", "-Sl", "ryoku")
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
	if !has("checkupdates") {
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
	if !has("snapper") {
		return 0
	}
	// `ryoku status` is polled from the GUI (Hub + pill) on a timer, no
	// controlling terminal. snapper wants root; interactive sudo with no tty
	// can't read a password, the PAM conversation fails, pam_faillock counts
	// each failure, and the account ends up locked out of sudo even with the
	// correct password. (yes, found this one the loud way.) so a read-only
	// status query MUST never escalate: skip the count unless a real terminal
	// drives us, and even then never prompt (sudo -n = already-cached cred only).
	if !stdinIsTTY() {
		return 0
	}
	out, err := runOut("sudo", "-n", "snapper", "-c", snapperConfig, "list")
	if err != nil {
		return 0
	}
	if n := countNonEmpty(out) - 2; n > 0 {
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

// cmdDeploy = the DEV loop: build the Go binaries + plugin and materialize
// from a repo checkout. production installs never see this; they pull
// everything from the [ryoku] pacman repo.
func cmdDeploy(_ []string) error {
	repo := os.Getenv("RYOKU_REPO")
	if repo == "" {
		return fmt.Errorf("set RYOKU_REPO to a Ryoku checkout for `ryoku deploy`")
	}
	script := filepath.Join(repo, "ryoku", "shell", "deploy.sh")
	if !exists(script) {
		return fmt.Errorf("not a Ryoku checkout (missing %s)", script)
	}
	return run(script)
}

// --- snapper pre/post (best-effort) ----------------------------------------

func snapperPre(desc string) string {
	if !has("snapper") {
		fmt.Fprintln(os.Stderr, "note: snapper not installed; skipping pre-update snapshot")
		return ""
	}
	// no root config -> the create below fails with an opaque
	// "config 'root' does not exist". point the user at the fix.
	if !exists("/etc/snapper/configs/root") {
		fmt.Fprintln(os.Stderr, "note: snapshot skipped, snapper root config missing; run 'ryoku doctor' to enable snapshots")
		return ""
	}
	out, err := runOut("sudo", "snapper", "-c", snapperConfig, "create",
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
	_ = sudo("snapper", "-c", snapperConfig, "create",
		"-t", "post", "--pre-number", pre, "-c", "number", "-d", desc)
}

// --- exec + path helpers ---------------------------------------------------

func run(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Stdin, cmd.Stdout, cmd.Stderr = os.Stdin, os.Stdout, os.Stderr
	return cmd.Run()
}

func sudo(args ...string) error { return run("sudo", args...) }

func runOut(name string, args ...string) (string, error) {
	out, err := exec.Command(name, args...).Output()
	return string(out), err
}

func has(name string) bool { _, err := exec.LookPath(name); return err == nil }

func exists(p string) bool { _, err := os.Stat(p); return err == nil }

// hyprLive: is a Hyprland session reachable for hyprctl.
func hyprLive() bool {
	return has("hyprctl") && exec.Command("hyprctl", "version").Run() == nil
}

// hyprPauseAutoreload stops Hyprland reloading the Lua config mid-swap, so a
// half-written file is never observed (would trip the emergency overlay).
func hyprPauseAutoreload() {
	if hyprLive() {
		_ = exec.Command("hyprctl", "keyword", "misc:disable_autoreload", "true").Run()
	}
}

// hyprReload applies the materialized config in one clean pass. the reload
// also restores auto-reload, since keywords reset from the config.
func hyprReload() {
	if hyprLive() {
		_ = exec.Command("hyprctl", "reload").Run()
	}
}

// restartShell: bring the shell daemon back up on the new binary, recovering
// one that died across the update. mirrors deploy.sh: stop the old daemon,
// drop orphaned surfaces holding the single-instance lock, start it detached
// so it outlives this process.
func restartShell() {
	if !has("ryoku-shell") {
		return
	}
	_ = exec.Command("ryoku-shell", "quit").Run()
	for i := 0; i < 20; i++ {
		if exec.Command("ryoku-shell", "ping").Run() != nil {
			break
		}
		time.Sleep(100 * time.Millisecond)
	}
	for _, c := range []string{"pill", "sidebar", "visualizer"} {
		_ = exec.Command("pkill", "-f", "qs -c "+c).Run()
	}
	time.Sleep(200 * time.Millisecond)
	cmd := exec.Command("setsid", "ryoku-shell", "daemon")
	logp := filepath.Join(xdg("XDG_STATE_HOME", ".local/state"), "ryoku-shell.log")
	_ = os.MkdirAll(filepath.Dir(logp), 0o755)
	if f, err := os.OpenFile(logp, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0o644); err == nil {
		cmd.Stdout, cmd.Stderr = f, f
	}
	_ = cmd.Start()
}

func installedVersion() string {
	out, err := runOut("pacman", "-Q", "ryoku-desktop")
	if err != nil {
		return ""
	}
	f := strings.Fields(strings.TrimSpace(out))
	if len(f) == 2 {
		return f[1]
	}
	return ""
}

func countNonEmpty(s string) int {
	n := 0
	sc := bufio.NewScanner(strings.NewReader(s))
	for sc.Scan() {
		if strings.TrimSpace(sc.Text()) != "" {
			n++
		}
	}
	return n
}

func home() string {
	if h, err := os.UserHomeDir(); err == nil {
		return h
	}
	return os.Getenv("HOME")
}

func xdg(envVar, fallback string) string {
	if v := os.Getenv(envVar); v != "" {
		return v
	}
	return filepath.Join(home(), fallback)
}

func configHome() string { return xdg("XDG_CONFIG_HOME", ".config") }

func baseConfigDir() string {
	if v := os.Getenv("RYOKU_CONFIG_BASE"); v != "" {
		return v
	}
	return "/usr/share/ryoku/config"
}

func materializeStatePath() string {
	return filepath.Join(xdg("XDG_STATE_HOME", ".local/state"), "ryoku", "materialized")
}

func die(format string, a ...any) {
	fmt.Fprintf(os.Stderr, "ryoku: "+format+"\n", a...)
	os.Exit(1)
}
