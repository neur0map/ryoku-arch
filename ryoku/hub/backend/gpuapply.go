package main

// gpuapply.go: the one-time, reversible "enable passthrough" (and its undo). It
// installs the stack, writes a small set of idempotent /etc files (kvmfr autoload +
// permissions, the libvirt hook, a polkit rule), adds the user to the libvirt/kvm
// groups, enables libvirtd, and -- only on an Intel host with IOMMU off -- adds the
// kernel cmdline token. Everything it writes, `disable` removes. It runs under
// pkexec (the lock.go pattern); a --dry-run prints the exact plan and touches
// nothing, which is what the Hub shows before the user confirms.

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
)

func runGpuApply(args []string) error {
	if len(args) == 0 {
		return fmt.Errorf("gpu apply needs enable|disable [--dry-run]")
	}
	action := args[0]
	if action != "enable" && action != "disable" {
		return fmt.Errorf("gpu apply: action must be enable or disable")
	}
	dryRun := false
	for _, a := range args[1:] {
		if a == "--dry-run" {
			dryRun = true
		}
	}
	// hook is an internal entrypoint libvirt calls; keep it on the same subcommand
	// tree but route it before the privilege dance.
	if dryRun {
		return applyPlan(action, invokingUser(), selfExe(), true)
	}
	if os.Geteuid() != 0 {
		return escalateApply(args)
	}
	return applyPlan(action, invokingUser(), selfExe(), false)
}

// escalateApply re-runs this binary as root via pkexec, preserving the invoking
// user's id so the privileged half can set the right group membership and udev
// owner (the lock.go greeter pattern).
func escalateApply(args []string) error {
	exe := selfExe()
	uid := strconv.Itoa(os.Getuid())
	full := append([]string{"env", "PKEXEC_UID=" + uid, exe, "gpu", "apply"}, args...)
	cmd := exec.Command("pkexec", full...)
	cmd.Stdout, cmd.Stderr, cmd.Stdin = os.Stdout, os.Stderr, os.Stdin
	return cmd.Run()
}

func selfExe() string {
	if e, err := os.Executable(); err == nil {
		return e
	}
	return "ryoku-hub"
}

// invokingUser is the human behind the action: PKEXEC_UID when escalated, else the
// current user's name.
func invokingUser() string {
	if u := os.Getenv("PKEXEC_UID"); u != "" {
		if name := userNameByID(u); name != "" {
			return name
		}
	}
	if u := os.Getenv("SUDO_USER"); u != "" {
		return u
	}
	return os.Getenv("USER")
}

func userNameByID(uid string) string {
	out, err := exec.Command("id", "-nu", uid).Output()
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(out))
}

type managedFile struct {
	rel     string
	content string
	mode    os.FileMode
}

func managedFiles(user, exe string) []managedFile {
	gpuBin := exe // ryoku-hub; the hook also needs ryoku-gpu, resolved below
	ryokuGpu := "ryoku-gpu"
	if p, err := exec.LookPath("ryoku-gpu"); err == nil {
		ryokuGpu = p
	}
	hook := "#!/bin/bash\n" +
		"# Managed by Ryoku (ryoku-hub gpu apply). libvirt calls this for every domain;\n" +
		"# we forward the Ryoku VM's prepare/release to ryoku-hub, which binds the dGPU to\n" +
		"# vfio-pci on start and hands it back on stop.\n" +
		"export RYOKU_GPU_BIN=" + shellQuote(ryokuGpu) + "\n" +
		"guest=\"$1\"; op=\"$2\"\n" +
		"case \"$op\" in\n" +
		"  prepare) " + shellQuote(gpuBin) + " gpu hook prepare \"$guest\" ;;\n" +
		"  release|stopped) " + shellQuote(gpuBin) + " gpu hook release \"$guest\" ;;\n" +
		"esac\n" +
		"exit 0\n"
	udev := fmt.Sprintf("SUBSYSTEM==\"kvmfr\", OWNER=\"%s\", GROUP=\"kvm\", MODE=\"0660\"\n", user)
	return []managedFile{
		{"etc/modules-load.d/ryoku-kvmfr.conf", "kvmfr\n", 0o644},
		{"etc/modprobe.d/ryoku-kvmfr.conf", "options kvmfr static_size_mb=128\n", 0o644},
		{"etc/udev/rules.d/99-ryoku-kvmfr.rules", udev, 0o644},
		{"etc/polkit-1/rules.d/50-ryoku-libvirt.rules", polkitRule, 0o644},
		{"etc/libvirt/hooks/qemu", hook, 0o755},
	}
}

const polkitRule = `// Managed by Ryoku. Let the libvirt group manage libvirt without a password so the
// Ryoku VM launches straight from the app launcher.
polkit.addRule(function(action, subject) {
  if (action.id == "org.libvirt.unix.manage" && subject.isInGroup("libvirt")) {
    return polkit.Result.YES;
  }
});
`

// installPackages, groups and services are the privileged actions that have no
// pure form; they are listed in the dry-run plan and executed only as root.
var passthroughPkgs = []string{"qemu-desktop", "libvirt", "edk2-ovmf", "swtpm", "dnsmasq", "looking-glass"}

func applyPlan(action, user, exe string, dryRun bool) error {
	files := managedFiles(user, exe)
	root := etcRoot()
	say := func(s string) { fmt.Println(planPrefix(dryRun) + s) }

	if action == "enable" {
		say("install packages: " + strings.Join(passthroughPkgs, " "))
		if !dryRun {
			snapshot("ryoku gpu passthrough enable")
			pacmanInstall(passthroughPkgs)
		}
		for _, f := range files {
			say("write " + "/" + f.rel)
			if !dryRun {
				if err := writeManaged(root, f); err != nil {
					return err
				}
			}
		}
		say("add " + user + " to groups: libvirt, kvm")
		say("enable libvirtd.socket and the default network")
		if !dryRun {
			run("gpasswd", "-a", user, "libvirt")
			run("gpasswd", "-a", user, "kvm")
			run("systemctl", "enable", "--now", "libvirtd.socket")
			run("udevadm", "control", "--reload-rules")
			run("virsh", "net-autostart", "default")
		}
		say("done. Log out and back in for group membership to take effect.")
		return nil
	}

	// disable: remove exactly what enable wrote.
	for _, f := range files {
		say("remove /" + f.rel)
		if !dryRun {
			_ = os.Remove(filepath.Join(root, f.rel))
		}
	}
	say("remove " + user + " from groups: libvirt, kvm")
	if !dryRun {
		run("gpasswd", "-d", user, "libvirt")
		run("gpasswd", "-d", user, "kvm")
		run("udevadm", "control", "--reload-rules")
	}
	say("done. The discrete GPU returns to the host on the next boot.")
	return nil
}

func planPrefix(dryRun bool) string {
	if dryRun {
		return "[plan] "
	}
	return "[apply] "
}

func writeManaged(root string, f managedFile) error {
	p := filepath.Join(root, f.rel)
	if err := os.MkdirAll(filepath.Dir(p), 0o755); err != nil {
		return err
	}
	if b, err := os.ReadFile(p); err == nil && string(b) == f.content {
		return nil // idempotent: already correct
	}
	return os.WriteFile(p, []byte(f.content), f.mode)
}

func etcRoot() string {
	if r := os.Getenv("RYOKU_ETC_ROOT"); r != "" {
		return r
	}
	return "/"
}

func pacmanInstall(pkgs []string) {
	run("pacman", append([]string{"-S", "--needed", "--noconfirm"}, pkgs...)...)
}

func snapshot(desc string) {
	if _, err := exec.LookPath("snapper"); err != nil {
		return
	}
	run("snapper", "-c", "root", "create", "--description", desc)
}

func run(name string, args ...string) {
	cmd := exec.Command(name, args...)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	_ = cmd.Run() // best-effort; non-fatal so one missing tool never aborts the rest
}

func shellQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", `'\''`) + "'"
}

// addCmdlineTokens appends each missing token to a Limine cmdline: line. Pure, so
// the (rare, Intel-only) bootloader edit is tested without a reboot.
func addCmdlineTokens(conf string, tokens []string) (string, bool) {
	lines := strings.Split(conf, "\n")
	changed := false
	for i, line := range lines {
		trimmed := strings.TrimSpace(line)
		if !strings.HasPrefix(trimmed, "cmdline:") {
			continue
		}
		for _, tok := range tokens {
			if !strings.Contains(line, tok) {
				line += " " + tok
				changed = true
			}
		}
		lines[i] = line
	}
	return strings.Join(lines, "\n"), changed
}
