// ryoku is the user-facing control CLI for the Ryoku distro: the single front
// door to updates, rollback, and the shell. It orchestrates pacman, yay, snapper,
// and the materialize step; it does not reimplement them.
//
//	ryoku update            snapshot -> pacman -Syu + yay -> materialize -> reload
//	ryoku rollback [id]     restore a snapper snapshot (or list them)
//	ryoku snapshots         list snapper snapshots
//	ryoku status            installed version, pending updates, snapshot count
//	ryoku materialize       lay the base configs into ~/.config (override-safe)
//	ryoku reload            restart the shell + reload Hyprland
//	ryoku deploy            DEV ONLY: build + materialize from a checkout
package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
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

  update         snapshot, then pacman -Syu + yay, materialize configs, reload
  rollback [id]  restore a snapper snapshot (no id: list them)
  snapshots      list snapper snapshots
  status         installed version, pending updates, snapshot count
  materialize    lay the base configs into ~/.config (keeps your overrides)
  reload         restart the shell and reload Hyprland
  deploy         DEV ONLY: deploy from a repo checkout (RYOKU_REPO)
`)
}

// cmdUpdate runs the full, safe update: a labeled pre-snapshot, the package
// transactions, the per-user config materialize, a shell reload, then a paired
// post-snapshot. Snapshots are best-effort so an unconfigured snapper never
// blocks an update, but a failed package step aborts before anything else.
func cmdUpdate(_ []string) error {
	pre := snapperPre("ryoku-update")
	publishRun("running", 0.05)
	defer publishRun("idle", 0)

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
	if err := materialize(); err != nil {
		return err
	}
	publishRun("running", 0.9)

	fmt.Println("==> Reloading shell")
	if err := run("ryoku-shell", "reload"); err != nil {
		fmt.Fprintf(os.Stderr, "warning: shell reload failed (changes apply on next login): %v\n", err)
	}

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
	installed := installedVersion()
	latest := latestAvailable("ryoku-desktop")
	ups := pendingUpdates()
	for _, u := range ups {
		if u.Name == "ryoku-desktop" {
			latest = u.New
		}
	}
	pending := len(ups)
	snaps := snapshotCount()
	available := pending > 0
	desktopBump := latest != "" && latest != installed

	if jsonOut {
		b, _ := json.Marshal(struct {
			InstalledVersion string      `json:"installedVersion"`
			LatestVersion    string      `json:"latestVersion"`
			Available        bool        `json:"available"`
			PendingUpdates   int         `json:"pendingUpdates"`
			Updates          []pkgUpdate `json:"updates"`
			Snapshots        int         `json:"snapshots"`
		}{installed, latest, available, pending, ups, snaps})
		fmt.Println(string(b))
		return nil
	}

	fmt.Printf("config base:   %s\n", baseConfigDir())
	fmt.Printf("ryoku-desktop: %s\n", orDash(installed))
	if desktopBump {
		fmt.Printf("available:     %s\n", latest)
	}
	if has("checkupdates") {
		fmt.Printf("pending:       %d package update(s)\n", pending)
	} else {
		fmt.Println("pending:       (install pacman-contrib for checkupdates)")
	}
	fmt.Printf("snapshots:     %d\n", snaps)
	return nil
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

type pkgUpdate struct {
	Name string `json:"name"`
	Old  string `json:"old"`
	New  string `json:"new"`
}

// pendingUpdates lists packages with a newer version available, via checkupdates
// (pacman-contrib), which syncs to a private database and so needs no root. The
// list is empty when the system is current or checkupdates is absent.
func pendingUpdates() []pkgUpdate {
	ups := []pkgUpdate{}
	if !has("checkupdates") {
		return ups
	}
	out, _ := runOut("checkupdates")
	sc := bufio.NewScanner(strings.NewReader(out))
	for sc.Scan() {
		f := strings.Fields(sc.Text())
		if len(f) >= 4 && f[2] == "->" {
			ups = append(ups, pkgUpdate{Name: f[0], Old: f[1], New: f[3]})
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
