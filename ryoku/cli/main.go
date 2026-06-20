// ryoku is the user-facing control CLI for the Ryoku distro: the single front
// door to updates, rollback, and the shell. It orchestrates pacman, yay, snapper,
// and the materialize step; it does not reimplement them.
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
  materialize    lay the base configs into ~/.config (keeps your overrides)
  reload         restart the shell and reload Hyprland
  deploy         DEV ONLY: deploy from a repo checkout (RYOKU_REPO)
  recovery       last resort: reset to main and redeploy (overwrites configs)
  doctor         run convergent reconcilers (idempotent stateful fixes)
`)
}

// cmdUpdate runs the full, safe update inside a snapper pre/post snapshot pair:
// the git update channel on a checkout (fast-forward + redeploy), or the package
// transactions + materialize + reload on a packaged install. Snapshots are
// best-effort so an unconfigured snapper never blocks an update, but a failed
// step aborts before anything else.
func cmdUpdate(_ []string) error {
	// Heal stateful drift the package and config layers cannot reach (e.g. a
	// swapfile stuck inside @) before snapshotting, so the pre-snapshot below can
	// be taken. Best-effort: a doctor finding never blocks the update.
	fmt.Println("==> Checking system")
	runDoctor(false, true)

	pre := snapperPre("ryoku-update")
	publishRun("running", 0.05)
	defer publishRun("idle", 0)

	// A Ryoku checkout updates through its git channel; a packaged install
	// updates through pacman. channelUpdate handles the former and reports
	// whether it applied; if not, fall through to the package transactions.
	if handled, err := channelUpdate(); err != nil {
		return err
	} else if handled {
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
	// Pause Hyprland's Lua auto-reload so the config swap is never observed
	// half-written, which would trip its emergency error overlay (no keybinds).
	hyprPauseAutoreload()
	if err := materialize(); err != nil {
		hyprReload()
		return err
	}
	publishRun("running", 0.9)

	fmt.Println("==> Reloading desktop")
	// One clean Hyprland reload applies the new config and restores auto-reload;
	// then restart the shell daemon so the new binary and QML both take effect.
	hyprReload()
	restartShell()

	snapperPost(pre, "ryoku-update")
	fmt.Println("==> Update complete")
	return nil
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
		fmt.Printf("ryoku-desktop: %s\n", orDash(r.Installed))
		if r.Latest != "" && r.Latest != r.Installed {
			fmt.Printf("available:     %s\n", r.Latest)
		}
		if has("checkupdates") {
			fmt.Printf("pending:       %d package update(s)\n", r.Behind)
		} else {
			fmt.Println("pending:       (install pacman-contrib for checkupdates)")
		}
	}
	fmt.Printf("snapshots:     %d\n", r.Snapshots)
	return nil
}

// statusReport is the data the Hub and the update island read from
// `ryoku status --json`: the installed and available versions, how far behind the
// machine is, and the per-item list. It is sourced from the git update channel on
// a Ryoku checkout (the live mirror) and from the [ryoku] pacman repo otherwise.
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

// buildStatus prefers the git update channel (a checkout tracking main); with no
// checkout it falls back to the pacman view of the [ryoku] repo.
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
		Installed: installed,
		Latest:    latest,
		Available: len(ups) > 0,
		Behind:    len(ups),
		Updates:   ups,
		Snapshots: snapshotCount(),
	}
}

// latestAvailable returns the version of pkg in the [ryoku] repo, or "" when the
// repo is not synced/configured. `pacman -Sl ryoku` prints "<repo> <pkg> <ver>".
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

// updateItem is one row in the update list: a package (name, old -> new) on the
// pacman path, or a commit (subject in Name, short hash in New) on the git
// channel.
type updateItem struct {
	Name string `json:"name"`
	Old  string `json:"old"`
	New  string `json:"new"`
}

// pendingUpdates lists packages with a newer version available, via checkupdates
// (pacman-contrib), which syncs to a private database and so needs no root. The
// list is empty when the system is current or checkupdates is absent.
func pendingUpdates() []updateItem {
	ups := []updateItem{}
	if !has("checkupdates") {
		return ups
	}
	// Bound the check: checkupdates syncs package databases over the network and
	// is polled by the update island, so it must never hang a status query; cap
	// it generously so a slow sync still completes.
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
	out, err := runOut("sudo", "snapper", "-c", snapperConfig, "list")
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

// cmdDeploy is the DEV loop: build the Go binaries + plugin and materialize from
// a repo checkout. Production installs never use this; they get everything from
// the [ryoku] pacman repo.
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

// hyprLive reports whether a Hyprland session is reachable for hyprctl.
func hyprLive() bool {
	return has("hyprctl") && exec.Command("hyprctl", "version").Run() == nil
}

// hyprPauseAutoreload stops Hyprland reloading its Lua config mid-swap, which
// would expose a half-written config and trip the emergency error overlay.
func hyprPauseAutoreload() {
	if hyprLive() {
		_ = exec.Command("hyprctl", "keyword", "misc:disable_autoreload", "true").Run()
	}
}

// hyprReload applies the materialized config in one clean pass; the reload also
// restores auto-reload, since keywords reset from the config.
func hyprReload() {
	if hyprLive() {
		_ = exec.Command("hyprctl", "reload").Run()
	}
}

// restartShell brings the shell daemon back on the new binary, recovering one
// that died across the update. Mirrors deploy.sh: stop the old daemon, clear
// orphaned surfaces that hold the single-instance lock, then start it detached so
// it outlives this process.
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
