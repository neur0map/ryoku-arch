package doctor

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"ryoku-cli/internal/sys"
)

var (
	uuidRE = regexp.MustCompile(`(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\b`)
	ipv4RE = regexp.MustCompile(`\b(?:\d{1,3}\.){3}\d{1,3}\b`)
	macRE  = regexp.MustCompile(`(?i)\b[0-9a-f]{2}(?::[0-9a-f]{2}){5}\b`)
)

// anonymize removes identifying information while keeping diagnostic data
// useful to maintainers.
func anonymize(s string) string {
	if home, err := os.UserHomeDir(); err == nil && home != "" {
		s = strings.ReplaceAll(s, home, "HOME")
	}

	if user := os.Getenv("USER"); user != "" {
		s = strings.ReplaceAll(s, "/home/"+user, "HOME")
		s = strings.ReplaceAll(s, user, "USER")
	}

	// Machine/session identifiers.
	s = uuidRE.ReplaceAllString(s, "UUID")
	s = macRE.ReplaceAllString(s, "MAC")

	// IP addresses are generally unnecessary for diagnosing desktop bugs.
	s = ipv4RE.ReplaceAllString(s, "IP")

	return s
}

var diagnosticPackages = []string{
	"ryoku",
	"ryoku-shell",
	"quickshell",
	"hyprland",
	"xdg-desktop-portal-hyprland",
	"limine",
	"snapper",
	"nvidia",
	"nvidia-utils",
	"pipewire",
	"wireplumber",
	"qt6-base",
}

func packageVersions(packages []string) map[string]string {
	versions := make(map[string]string, len(packages))

	for _, pkg := range packages {
		out, err := exec.Command("pacman", "-Q", pkg).Output()
		if err != nil {
			versions[pkg] = "<not installed>"
			continue
		}

		fields := strings.Fields(string(out))
		if len(fields) >= 2 {
			versions[pkg] = fields[1]
		} else {
			versions[pkg] = "<unknown>"
		}
	}

	return versions
}

// ---- diagnostic report -------------------------------------------------------

func reportPath(override string) string {
	if override != "" {
		return override
	}
	return filepath.Join(sys.Xdg("XDG_STATE_HOME", ".local/state"), "ryoku", "doctor-report.txt")
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

// gatherReport: one self-contained text report. doctor findings, then the
// system state a maintainer needs to diagnose the unknown. safe to share --
// system state + recent error logs, no secrets.
func gatherReport(findings []finding) string {
	var b strings.Builder
	line := func(f string, a ...any) { fmt.Fprintf(&b, anonymize(fmt.Sprintf(f, a...))+"\n") }
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
	line("state dir:\n%s", captureOut("ls", "-la", filepath.Join(sys.Xdg("XDG_STATE_HOME", ".local/state"), "ryoku")))
	line("[ryoku] repo configured: %v", strings.Contains(readFileSafe("/etc/pacman.conf"), "[ryoku]"))

	section("storage (btrfs)")
	cmd("sudo", "-n", "btrfs", "filesystem", "usage", "/")
	cmd("sudo", "-n", "btrfs", "device", "stats", "/")
	line("/proc/swaps:\n%s", readFileSafe("/proc/swaps"))
	line("/etc/conf.d/snapper:\n%s", readFileSafe("/etc/conf.d/snapper"))

	section("packages")

	line("checked packages:")
	for _, pkg := range diagnosticPackages {
		line("  - %s", pkg)
	}

	line("")
	line("installed versions:")

	versions := packageVersions(diagnosticPackages)
	for _, pkg := range diagnosticPackages {
		line("  %-32s %s", pkg, versions[pkg])
	}

	line("")
	cmd("pacman", "-Qtdq")
	cmd("pacman", "-Dk")

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
	// vendor-agnostic GPU-hang signatures: amdgpu (reset/wedged/VRAM lost/ring),
	// nvidia (NVRM Xid), i915 (GPU HANG). skip a bare "Xid" so an r8169 NIC's
	// "XID" line doesn't get mistaken for a GPU fault. search across boots: a
	// crash needs a reboot, so the evidence is in the previous boot, not the
	// current one.
	const gpuHang = `GPU reset begin|device wedged|VRAM is lost|ring .* reset failed|NVRM: Xid|GPU HANG`
	line("GPU resets/hangs (last 14 days): %s", captureOut("sh", "-c",
		"journalctl --no-pager --since '-14 days' -g '"+gpuHang+"' 2>/dev/null | grep -cE '"+gpuHang+"'"))
	line("recent GPU reset/hang lines:\n%s", tailLines(captureOut("sh", "-c",
		"journalctl --no-pager --since '-14 days' -g '"+gpuHang+"' 2>/dev/null || true"), 12))
	line("compositor/session coredumps:\n%s", captureOut("sh", "-c",
		"coredumpctl list --no-pager 2>/dev/null | grep -iE 'Hyprland|Xwayland|quickshell|aquamarine' | tail -10 || true"))

	return b.String()
}
