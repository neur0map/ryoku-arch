package main

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestManagedFilesContent(t *testing.T) {
	files := managedFiles("nero", "/usr/bin/ryoku-hub")
	var hook *managedFile
	for i := range files {
		if files[i].rel == "etc/libvirt/hooks/qemu" {
			hook = &files[i]
		}
	}
	if hook == nil {
		t.Fatal("no libvirt hook in managed files")
	}
	if !strings.Contains(hook.content, "ryoku") {
		t.Error("hook must contain the ryoku marker (hookInstalled checks for it)")
	}
	if hook.mode != 0o755 {
		t.Errorf("hook mode = %o, want 0755", hook.mode)
	}
	if !containsFile(files, "etc/udev/rules.d/99-ryoku-kvmfr.rules", `OWNER="nero"`) {
		t.Error("kvmfr udev rule must own the device to the invoking user")
	}
}

func TestWriteManagedIdempotent(t *testing.T) {
	root := t.TempDir()
	f := managedFile{"etc/modules-load.d/ryoku-kvmfr.conf", "kvmfr\n", 0o644}
	if err := writeManaged(root, f); err != nil {
		t.Fatal(err)
	}
	if err := writeManaged(root, f); err != nil {
		t.Fatal(err) // identical content is a no-op, never an error
	}
	b, _ := os.ReadFile(filepath.Join(root, f.rel))
	if string(b) != "kvmfr\n" {
		t.Errorf("content = %q", b)
	}
}

func TestApplyPlanDryRunWritesNothing(t *testing.T) {
	root := t.TempDir()
	t.Setenv("RYOKU_ETC_ROOT", root)
	if err := applyPlan("enable", "nero", "/usr/bin/ryoku-hub", true); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(root, "etc/libvirt/hooks/qemu")); err == nil {
		t.Error("a dry-run must not write any file")
	}
}

func TestAddCmdlineTokens(t *testing.T) {
	conf := "/boot/vmlinuz\n    cmdline: quiet splash\nmodule_path: boot():/boot\n"
	out, changed := addCmdlineTokens(conf, []string{"intel_iommu=on", "iommu=pt"})
	if !changed {
		t.Fatal("expected the cmdline to change")
	}
	if !strings.Contains(out, "quiet splash intel_iommu=on iommu=pt") {
		t.Errorf("cmdline = %q", out)
	}
	out2, changed2 := addCmdlineTokens(out, []string{"intel_iommu=on", "iommu=pt"})
	if changed2 || out2 != out {
		t.Error("adding the same tokens twice must be a no-op")
	}
}

func containsFile(files []managedFile, rel, want string) bool {
	for _, f := range files {
		if f.rel == rel {
			return strings.Contains(f.content, want)
		}
	}
	return false
}
