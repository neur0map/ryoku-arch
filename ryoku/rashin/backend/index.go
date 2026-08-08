package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

// Reindex regenerates the machine-owned vault docs. Every probe is best
// effort, so a missing tool degrades one section rather than failing the index.
func Reindex() error {
	if err := EnsureVault(); err != nil {
		return err
	}
	docs := []struct {
		name, header, body string
	}{
		{"system.md", systemHeader, systemBody()},
		{"desktop.md", desktopHeader, desktopBody()},
		{"packages.md", packagesHeader, packagesBody()},
	}
	for _, d := range docs {
		if err := writeVaultDoc(d.name, d.header, d.body); err != nil {
			return err
		}
	}
	if err := writeRepoVaultDoc(); err != nil {
		return err
	}
	if err := writeUserVaultDoc(); err != nil {
		return err
	}
	return WriteHabits()
}

// ReindexUser refreshes only the user-owned changes layer; cheap enough for
// the watcher to run whenever the live config drifts.
func ReindexUser() error {
	if err := EnsureVault(); err != nil {
		return err
	}
	return writeUserVaultDoc()
}

const systemHeader = "# System\n" +
	"\n" +
	"Hardware, kernel, GPU, disks, and displays. Generated: the content between the\n" +
	"markers is overwritten on every reindex."

const desktopHeader = "# Ryoku desktop map\n" +
	"\n" +
	"Where every subsystem's config lives, the binary that owns it, and how to\n" +
	"reload it. Read this before searching the filesystem. Generated: the content\n" +
	"between the markers is overwritten on every reindex."

const packagesHeader = "# Packages\n" +
	"\n" +
	"Installed package counts, the explicit set, and pending updates. Generated:\n" +
	"the content between the markers is overwritten on every reindex."

// writeVaultDoc lays down a generated doc as header + fenced body on first
// write, and thereafter rewrites only the fenced body so a user's out-of-fence
// edits (including the header) survive.
func writeVaultDoc(name, header, body string) error {
	path := filepath.Join(VaultDir(), name)
	existing := readFileOrEmpty(path)
	var doc string
	if existing == "" {
		doc = header + "\n\n" + buildFence(body) + "\n"
	} else {
		doc = ReplaceFenced(existing, body)
	}
	return atomicWrite(path, []byte(doc), 0o644)
}

func systemBody() string {
	var b strings.Builder
	model, cores := cpuModelCores()
	total, _ := memTotalUsed()

	b.WriteString("## CPU\n\n")
	fmt.Fprintf(&b, "- Model: %s\n", orUnknown(model))
	fmt.Fprintf(&b, "- Logical cores: %s\n\n", orUnknownInt(cores))

	b.WriteString("## Memory\n\n")
	if total > 0 {
		fmt.Fprintf(&b, "- Total: %s\n\n", humanBytes(total))
	} else {
		b.WriteString("- Total: unknown\n\n")
	}

	b.WriteString("## Kernel\n\n")
	fmt.Fprintf(&b, "- Release: %s\n\n", orUnknown(kernelRelease()))

	b.WriteString("## GPU\n\n")
	if gpus := gpuDescribe(); len(gpus) > 0 {
		for _, g := range gpus {
			fmt.Fprintf(&b, "- %s\n", g)
		}
		b.WriteString("\n")
	} else {
		b.WriteString("- (none detected)\n\n")
	}

	b.WriteString("## Displays\n\n")
	if mons := monitorRows(); len(mons) > 0 {
		for _, m := range mons {
			fmt.Fprintf(&b, "- %s\n", m)
		}
		b.WriteString("\n")
	} else {
		b.WriteString("- (none detected)\n\n")
	}

	b.WriteString("## Disks\n\n")
	if rows := diskRows(); len(rows) > 0 {
		b.WriteString("| Device | Mount | Size | Used |\n|---|---|---|---|\n")
		for _, r := range rows {
			b.WriteString(r + "\n")
		}
	} else {
		b.WriteString("(no block devices detected)\n")
	}
	return b.String()
}

// desktopMapRow is one verified line of the Ryoku map.
type desktopMapRow struct {
	subsystem, path, owner, reload string
}

// desktopMap is distilled from docs/structure.md, docs/cli.md, the hub and shell
// READMEs, and the shell IPC surface. Every path, owner, and reload command is
// verified against the repo. The shell exposes no per-component restart verb, so
// shell surfaces reload via `ryoku reload`.
var desktopMap = []desktopMapRow{
	{"Hyprland (window manager)", "~/.config/hypr/", "Hyprland (Lua config)", "hyprctl reload"},
	{"Shell surfaces (pill, sidebar, ryoshot, widgets, launcher, hub)", "~/.config/quickshell/", "ryoku-shell daemon", "ryoku reload"},
	{"Terminal", "~/.config/kitty/", "kitty", "relaunch kitty"},
	{"Shell + prompt", "~/.config/fish/config.fish, ~/.config/starship.toml", "fish, starship", "open a new shell"},
	{"Editor", "~/.config/nvim/", "Neovim (LazyVim)", "relaunch nvim"},
	{"File manager", "~/.config/yazi/", "yazi", "relaunch yazi"},
	{"Ryoku CLI", "binary `ryoku`; state ~/.local/state/ryoku/", "ryoku", "ryoku update | rollback | status | materialize | reload"},
	{"Hub state", "~/.config/ryoku/hub.toml", "ryoku-hub (Ryoku Settings)", "written by Ryoku Settings; no reload"},
	{"Theme + colour source", "~/.config/ryoku/theme.json", "ryoku-hub", "ryoku-shell wallpaper repaint"},
	{"Palette", "~/.cache/ryoku/colors.json", "ryoku-shell daemon (matugen)", "ryoku-shell wallpaper repaint"},
	{"Packages", "pacman + yay database", "pacman, yay", "ryoku update"},
	{"System vault", "~/.local/share/ryoku/rashin/", "ryoku-rashin", "ryoku-rashin index"},
}

// ryokuPackages are queried for installed versions in desktop.md.
var ryokuPackages = []string{"ryoku-shell", "ryoku-hub", "ryoku", "ryoku-blobs", "ryoku-desktop", "ryoku-rashin"}

func desktopBody() string {
	var b strings.Builder
	b.WriteString("## Subsystem map\n\n")
	b.WriteString("| Subsystem | Config path | Owner | Reload |\n|---|---|---|---|\n")
	for _, r := range desktopMap {
		fmt.Fprintf(&b, "| %s | %s | %s | %s |\n", r.subsystem, mdCell(r.path), r.owner, mdCell(r.reload))
	}
	b.WriteString("\n## Ryoku package versions\n\n")
	any := false
	for _, pkg := range ryokuPackages {
		if v := pacmanVersion(pkg); v != "" {
			fmt.Fprintf(&b, "- %s %s\n", pkg, v)
			any = true
		} else {
			fmt.Fprintf(&b, "- %s (not installed)\n", pkg)
		}
	}
	if !any {
		b.WriteString("\n(no Ryoku packages installed; likely a dev checkout)\n")
	}
	return b.String()
}

func packagesBody() string {
	var b strings.Builder
	if out, ok := probe(5, "pacman", "-Qq"); ok {
		fmt.Fprintf(&b, "## Total installed\n\n%d packages\n\n", len(nonEmptyLines(out)))
	} else {
		b.WriteString("## Total installed\n\n(pacman unavailable)\n\n")
	}
	if out, ok := probe(5, "pacman", "-Qqe"); ok {
		lines := nonEmptyLines(out)
		b.WriteString("## Explicitly installed\n\n")
		fmt.Fprintf(&b, "<details><summary>%d explicit packages</summary>\n\n", len(lines))
		for _, l := range lines {
			fmt.Fprintf(&b, "- %s\n", l)
		}
		b.WriteString("\n</details>\n\n")
	}
	// checkupdates exits non-zero (2) when nothing is pending; skip the section
	// on any error or a missing tool rather than reporting a misleading zero.
	if out, ok := probe(5, "checkupdates"); ok {
		fmt.Fprintf(&b, "## Pending updates\n\n%d packages\n", len(nonEmptyLines(out)))
	}
	return strings.TrimRight(b.String(), "\n") + "\n"
}

func gpuDescribe() []string {
	if _, err := exec.LookPath("ryoku-gpu-detect"); err == nil {
		if out, ok := probe(5, "ryoku-gpu-detect"); ok {
			if lines := nonEmptyLines(out); len(lines) > 0 {
				return lines
			}
		}
	}
	out, ok := probe(5, "lspci")
	if !ok {
		return nil
	}
	var gpus []string
	for _, l := range nonEmptyLines(out) {
		ll := strings.ToLower(l)
		if strings.Contains(ll, "vga compatible controller") ||
			strings.Contains(ll, "3d controller") ||
			strings.Contains(ll, "display controller") {
			gpus = append(gpus, strings.TrimSpace(l))
		}
	}
	return gpus
}

type hyprMonitor struct {
	Name        string  `json:"name"`
	Description string  `json:"description"`
	Width       int     `json:"width"`
	Height      int     `json:"height"`
	RefreshRate float64 `json:"refreshRate"`
	Scale       float64 `json:"scale"`
}

func monitorRows() []string {
	out, ok := probe(5, "hyprctl", "monitors", "-j")
	if !ok {
		return nil
	}
	var ms []hyprMonitor
	if json.Unmarshal([]byte(out), &ms) != nil {
		return nil
	}
	var rows []string
	for _, m := range ms {
		row := fmt.Sprintf("%s: %dx%d@%.0fHz, scale %g", m.Name, m.Width, m.Height, m.RefreshRate, m.Scale)
		if m.Description != "" {
			row += " (" + m.Description + ")"
		}
		rows = append(rows, row)
	}
	return rows
}

// lsblkNode mirrors `lsblk -J` with nullable string fields, tolerating any that
// the running lsblk omits.
type lsblkNode struct {
	Name       string      `json:"name"`
	Mountpoint *string     `json:"mountpoint"`
	Size       *string     `json:"size"`
	Fsused     *string     `json:"fsused"`
	Children   []lsblkNode `json:"children"`
}

func diskRows() []string {
	out, ok := probe(5, "lsblk", "-J", "-o", "NAME,MOUNTPOINT,SIZE,FSUSED")
	if !ok {
		return nil
	}
	var doc struct {
		BlockDevices []lsblkNode `json:"blockdevices"`
	}
	if json.Unmarshal([]byte(out), &doc) != nil {
		return nil
	}
	var rows []string
	var walk func(n lsblkNode)
	walk = func(n lsblkNode) {
		if n.Mountpoint != nil && *n.Mountpoint != "" {
			rows = append(rows, fmt.Sprintf("| %s | %s | %s | %s |",
				n.Name, *n.Mountpoint, orDash(n.Size), orDash(n.Fsused)))
		}
		for _, c := range n.Children {
			walk(c)
		}
	}
	for _, d := range doc.BlockDevices {
		walk(d)
	}
	return rows
}

func pacmanVersion(pkg string) string {
	out, ok := probe(5, "pacman", "-Q", pkg)
	if !ok {
		return ""
	}
	fields := strings.Fields(strings.TrimSpace(out))
	if len(fields) >= 2 {
		return fields[1]
	}
	return ""
}

// probe runs a command with a timeout, returning its stdout and whether it
// succeeded. It is the single best-effort exec path for the indexer.
func probe(seconds int, name string, args ...string) (string, bool) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(seconds)*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, name, args...).Output()
	if err != nil {
		return "", false
	}
	return string(out), true
}

func nonEmptyLines(s string) []string {
	var out []string
	for _, l := range strings.Split(s, "\n") {
		if t := strings.TrimSpace(l); t != "" {
			out = append(out, t)
		}
	}
	return out
}

func orUnknown(s string) string {
	if s == "" {
		return "unknown"
	}
	return s
}

func orUnknownInt(n int) string {
	if n <= 0 {
		return "unknown"
	}
	return fmt.Sprintf("%d", n)
}

func orDash(s *string) string {
	if s == nil || *s == "" {
		return "-"
	}
	return *s
}

// mdCell escapes the pipe so a path or command never breaks the table.
func mdCell(s string) string {
	return strings.ReplaceAll(s, "|", "\\|")
}

func humanBytes(n int64) string {
	const unit = 1024
	if n < unit {
		return fmt.Sprintf("%d B", n)
	}
	div, exp := int64(unit), 0
	for x := n / unit; x >= unit; x /= unit {
		div *= unit
		exp++
	}
	return fmt.Sprintf("%.1f %ciB", float64(n)/float64(div), "KMGTPE"[exp])
}
