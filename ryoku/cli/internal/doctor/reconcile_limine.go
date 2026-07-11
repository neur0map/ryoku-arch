package doctor

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"ryoku-cli/internal/sys"
)

// ---- reconciler: limine boot menu layout --------------------------------------

// limine-entry-tool (the stack behind limine-mkinitcpio-hook and
// limine-snapper-sync) manages exactly one config: /boot/limine.conf, the ESP
// root. Limine itself scans /boot/limine/limine.conf BEFORE /boot/limine.conf
// on the same partition, so a config in that older location shadows every
// generated entry -- UKIs, the Snapshots submenu, everything -- and the
// firmware keeps showing the frozen install-time menu. earlier installers
// wrote exactly that shadow file, and also hand-copied the Limine binary to
// EFI/limine/limine.efi, a path the tool never refreshes (it deploys
// EFI/limine/limine_x64.efi), so the booted bootloader silently ages while
// the package updates. this reconciler migrates both: merge the shadow's
// branding into the tool-managed config and remove it, then re-deploy the
// binary onto the tool's path and retire the stale NVRAM entry.
//
// limineBranding mirrors system/boot/limine/limine.conf (the globals): keep
// the two in sync so a doctored box matches a fresh install.
const limineBranding = `timeout: 3
default_entry: 2
interface_branding: Ryoku Bootloader
interface_branding_color: F25623
interface_help_color: F25623
hash_mismatch_panic: no

term_background: 171717
backdrop: 171717
term_palette: 171717;aeab94;F25623;4D4D4D;88A57D;F56E0F;8A8A8A;bcbfbc
term_palette_bright: 333333;aeab94;F25623;4D4D4D;88A57D;F56E0F;8A8A8A;757d75
term_foreground: CCD0CF
term_foreground_bright: CCD0CF
term_background_bright: 333333
`

const (
	limineESPConf   = "/boot/limine.conf"
	limineShadow    = "/boot/limine/limine.conf"
	limineLegacyEFI = "/boot/EFI/limine/limine.efi"
	limineToolEFI   = "/boot/EFI/limine/limine_x64.efi"
)

type limineLayoutOutcome int

const (
	limineLayoutSkip limineLayoutOutcome = iota
	limineLayoutOK
	limineLayoutUnreadable
	limineLayoutMigrate
)

// limineLayoutState: the slice of /boot reconcileLimineLayout looks at,
// lifted to a value so planLimineLayout stays unit-testable.
type limineLayoutState struct {
	limineInstalled bool
	espConfExists   bool
	espConf         string // "" when absent or unreadable
	espConfReadable bool
	shadowExists    bool
	shadowConf      string
	shadowReadable  bool
	legacyEFIExists bool
	toolEFIExists   bool
	installerTool   bool // limine-install on PATH
}

// planLimineLayout picks the branch from observed state. pure, no IO.
func planLimineLayout(s limineLayoutState) (limineLayoutOutcome, []string) {
	if !s.limineInstalled {
		return limineLayoutSkip, nil
	}
	if !s.espConfExists && !s.shadowExists {
		// not a limine-booted box (or the ESP isn't at /boot); nothing to own.
		return limineLayoutSkip, nil
	}
	if (s.espConfExists && !s.espConfReadable) || (s.shadowExists && !s.shadowReadable) {
		return limineLayoutUnreadable, nil
	}
	var actions []string
	if s.shadowExists {
		actions = append(actions, fmt.Sprintf("merge %s into %s and remove it (it shadows the generated boot entries: kernels, snapshots)", limineShadow, limineESPConf))
	} else if limineHasBootTree(s.espConf) {
		if limineDefaultEntry(s.espConf) == "1" {
			actions = append(actions, "point default_entry at the newest kernel (entry 1 is the Ryoku directory, which cannot autoboot)")
		}
		if limineDirtyRoot(s.espConf) {
			actions = append(actions, "strip the leftover boot stanza from the Ryoku boot-menu directory (a directory that is also a boot entry cannot autoboot; the countdown loops)")
		}
	}
	if s.legacyEFIExists {
		actions = append(actions, fmt.Sprintf("retire the stale hand-copied bootloader %s for the package-refreshed %s", limineLegacyEFI, limineToolEFI))
	}
	if len(actions) == 0 {
		return limineLayoutOK, nil
	}
	return limineLayoutMigrate, actions
}

func gatherLimineLayoutState() limineLayoutState {
	s := limineLayoutState{
		limineInstalled: sys.PkgInstalled("limine"),
		legacyEFIExists: sys.Exists(limineLegacyEFI),
		toolEFIExists:   sys.Exists(limineToolEFI),
		installerTool:   sys.Has("limine-install"),
	}
	if b, err := os.ReadFile(limineESPConf); err == nil {
		s.espConfExists, s.espConfReadable, s.espConf = true, true, string(b)
	} else if sys.Exists(limineESPConf) {
		s.espConfExists = true
	}
	if b, err := os.ReadFile(limineShadow); err == nil {
		s.shadowExists, s.shadowReadable, s.shadowConf = true, true, string(b)
	} else if sys.Exists(limineShadow) {
		s.shadowExists = true
	}
	return s
}

func reconcileLimineLayout(checkOnly bool) recResult {
	st := gatherLimineLayoutState()
	outcome, actions := planLimineLayout(st)
	switch outcome {
	case limineLayoutSkip:
		return okRes("not a limine-managed boot on this box")
	case limineLayoutUnreadable:
		return warnRes("cannot read the limine config under /boot to verify the boot menu layout").
			withFix("sudo ryoku doctor")
	case limineLayoutOK:
		return okRes("boot menu lives in /boot/limine.conf; nothing shadows it")
	}
	if checkOnly {
		return wouldRes("limine boot layout needs migration: %s", strings.Join(actions, "; ")).
			withFix("ryoku doctor (applies the migration)")
	}
	return migrateLimineLayout(st)
}

// migrateLimineLayout applies the plan: config first (that alone puts the
// generated kernel + snapshot entries back on screen at next boot), then the
// binary. every step is separately recoverable; the box stays bootable at
// any interruption point because the merged config is written before the
// shadow is removed, and the tool EFI is deployed before the legacy one is
// retired.
func migrateLimineLayout(st limineLayoutState) recResult {
	var done []string

	if st.shadowExists || (limineHasBootTree(st.espConf) && (limineDefaultEntry(st.espConf) == "1" || limineDirtyRoot(st.espConf))) {
		merged := mergeLimineConf(st.espConf, st.shadowConf)
		if st.espConfExists {
			_ = sys.Run("sudo", "cp", limineESPConf, limineESPConf+".ryoku-bak")
		}
		if err := writeBootFile(limineESPConf, merged); err != nil {
			return failRes("writing %s: %v", limineESPConf, err).
				withFix("re-run with sudo available; the old configs were left untouched")
		}
		done = append(done, "merged boot menu into "+limineESPConf)
		if st.shadowExists {
			if err := sys.Run("sudo", "rm", "-f", limineShadow); err != nil {
				return failRes("removing the shadowing %s: %v (the merged config is written, but limine still reads the shadow)", limineShadow, err).
					withFix("sudo rm %s", limineShadow)
			}
			_ = exec.Command("sudo", "rmdir", "/boot/limine").Run() // only if empty
			done = append(done, "removed the shadowing "+limineShadow)
		}
	}

	if st.legacyEFIExists {
		// Retire the legacy hand-copied bootloader for the package-refreshed
		// path, but NEVER before a boot entry points at the new binary. Deleting
		// the only NVRAM entry with nothing to replace it drops the machine off
		// the firmware boot menu entirely: the "boot option gone after an
		// update, not even in the BIOS" failure.
		if st.installerTool {
			// deploys EFI/limine/limine_x64.efi + the EFI/BOOT fallback and
			// registers the NVRAM entry (deduped by partition uuid + path).
			if err := sys.Run("sudo", "limine-install"); err != nil {
				return warnRes("boot menu migrated (%s), but limine-install failed: %v", strings.Join(done, "; "), err).
					withFix("sudo limine-install, then sudo rm %s", limineLegacyEFI)
			}
		} else if sys.Exists("/usr/share/limine/BOOTX64.EFI") {
			// no tool: deploy the fresh binary at the package path, then register
			// the entry the way the installer does. if the entry cannot be
			// written, leave the working legacy boot path alone rather than
			// strand the machine.
			if err := sys.Run("sudo", "cp", "/usr/share/limine/BOOTX64.EFI", limineToolEFI); err != nil {
				return warnRes("boot menu migrated (%s), but could not deploy %s: %v", strings.Join(done, "; "), limineToolEFI, err).
					withFix("sudo cp /usr/share/limine/BOOTX64.EFI %s", limineToolEFI)
			}
			if !hasRyokuBootEntry(efibootmgrOutput()) {
				if err := registerRyokuBootEntry(); err != nil {
					return warnRes("boot menu migrated (%s), but could not register a boot entry for %s (%v); left the current entry in place so the machine still boots", strings.Join(done, "; "), limineToolEFI, err).
						withFix("install limine-mkinitcpio-hook, then sudo ryoku doctor")
				}
			}
		}
		// only retire the stale entry + binary once a live NVRAM entry loads the
		// package-refreshed bootloader.
		if sys.Exists(limineToolEFI) && hasRyokuBootEntry(efibootmgrOutput()) {
			for _, boot := range staleLimineBootNums(efibootmgrOutput()) {
				_ = sys.Run("sudo", "efibootmgr", "-q", "-b", boot, "-B")
			}
			if err := sys.Run("sudo", "rm", "-f", limineLegacyEFI); err != nil {
				return warnRes("boot menu migrated (%s), but could not remove the stale %s: %v", strings.Join(done, "; "), limineLegacyEFI, err).
					withFix("sudo rm %s", limineLegacyEFI)
			}
			done = append(done, "bootloader binary now on the package-refreshed path")
		}
	}

	// the shadow (or the rewrite) may have carried a Windows chainload block;
	// re-assert it against the merged config. best-effort, needs root mounts.
	if sys.Has("ryoku-windows-entry") {
		_ = exec.Command("sudo", "ryoku-windows-entry", "sync").Run()
	}

	return fixedRes("%s (snapshots and new kernels appear in the boot menu from the next boot)", strings.Join(done, "; "))
}

// limineHasBootTree: has limine-mkinitcpio-hook taken over the file? two
// shapes qualify: the older tool writes a standalone expanded directory
// ("/+Ryoku"); 1.37+ adopts the flat "/Ryoku Linux" placeholder as the menu
// directory and nests "//<kernel>" sub-entries under it. either means a
// directory sits at entry 1, which cannot autoboot. the flat installer
// placeholder and foreign leaf entries carry neither a "/+" nor a "//".
func limineHasBootTree(conf string) bool {
	for _, line := range strings.Split(conf, "\n") {
		if strings.HasPrefix(line, "/+") {
			return true
		}
		if strings.HasPrefix(strings.TrimSpace(line), "//") {
			return true
		}
	}
	return false
}

// limineDefaultEntry: the value of the global default_entry option, "" when
// absent.
func limineDefaultEntry(conf string) string {
	for _, line := range strings.Split(conf, "\n") {
		if v, ok := strings.CutPrefix(strings.TrimSpace(line), "default_entry:"); ok {
			return strings.TrimSpace(v)
		}
	}
	return ""
}

// liminePlaceholderBodyKeys: the local boot options ryoku's flat "/Ryoku
// Linux" placeholder carries (installer bootloader.sh with_entry). when
// limine-entry-tool 1.37+ adopts that placeholder as the menu directory and
// nests the "//<kernel>" UKIs under it, this stanza is left wedged between the
// directory title and its first sub-entry -- where Limine's grammar allows
// only a `comment`. a directory that is also a boot entry cannot autoboot: the
// timeout resolves nothing bootable and the countdown restarts forever.
var liminePlaceholderBodyKeys = []string{
	"protocol:", "kernel_path:", "module_path:", "path:", "cmdline:",
}

func liminePlaceholderBodyKey(trimmed string) bool {
	for _, k := range liminePlaceholderBodyKeys {
		if strings.HasPrefix(trimmed, k) {
			return true
		}
	}
	return false
}

// limineDirtyRoot reports whether the "/Ryoku Linux" menu directory still
// carries the leftover placeholder boot stanza before its first sub-entry.
func limineDirtyRoot(conf string) bool {
	return stripLiminePlaceholderBody(conf) != conf
}

// stripLiminePlaceholderBody removes the flat-placeholder boot stanza (and the
// blank lines around it) wedged under the "/Ryoku Linux" directory title,
// keeping the title, any `comment:` lines, and every sub-entry. it is a no-op
// unless "/Ryoku Linux" is a directory (a "//" sub-entry follows its head), so
// the legitimate flat placeholder of an offline install is never touched.
func stripLiminePlaceholderBody(conf string) string {
	lines := strings.Split(conf, "\n")
	start := -1
	for i, ln := range lines {
		if ln == "/Ryoku Linux" {
			start = i
			break
		}
	}
	if start < 0 {
		return conf
	}
	var drop []int
	isDir := false
	for i := start + 1; i < len(lines); i++ {
		trimmed := strings.TrimSpace(lines[i])
		if strings.HasPrefix(trimmed, "//") { // a sub-entry: it is a directory
			isDir = true
			break
		}
		if strings.HasPrefix(lines[i], "/") { // next top-level entry: no sub-entry
			break
		}
		if trimmed == "" || liminePlaceholderBodyKey(trimmed) {
			drop = append(drop, i)
		}
	}
	if !isDir || len(drop) == 0 {
		return conf
	}
	dropSet := make(map[int]bool, len(drop))
	for _, i := range drop {
		dropSet[i] = true
	}
	var out []string
	for i, ln := range lines {
		if dropSet[i] {
			continue
		}
		out = append(out, ln)
	}
	return strings.Join(out, "\n")
}

// limineBrandedKeys: global options the canonical branding header owns. when
// merging, lines carrying these are dropped from the existing prelude so the
// header's values win without duplicates. everything else a user (or the
// tool) put in the prelude -- quiet, remember_last_entry, interface_resolution,
// macros -- survives.
var limineBrandedKeys = []string{
	"timeout:", "default_entry:", "interface_branding:",
	"interface_branding_color:", "interface_branding_colour:",
	"interface_help_color:", "interface_help_colour:",
	"interface_help_color_bright:", "interface_help_colour_bright:",
	"hash_mismatch_panic:", "term_background:", "backdrop:",
	"term_palette:", "term_palette_bright:", "term_foreground:",
	"term_foreground_bright:", "term_background_bright:",
}

// mergeLimineConf builds the migrated /boot/limine.conf: the canonical Ryoku
// branding header, then whatever non-branding globals the base prelude
// carried, then the base's entries verbatim. the base is the ESP-root config
// when the tool's boot tree lives there (never throw generated entries
// away), else the shadow (the menu the firmware was actually showing).
// default_entry falls back to 1 when the menu is still flat: with no
// directory at entry 1, 2 would autoboot the second flat entry (e.g.
// Windows).
func mergeLimineConf(espConf, shadowConf string) string {
	base := espConf
	if !limineHasBootTree(espConf) && shadowConf != "" {
		base = shadowConf
	}
	prelude, body := splitLimineConf(base)
	body = stripLiminePlaceholderBody(body)

	var kept []string
	for _, line := range strings.Split(prelude, "\n") {
		t := strings.TrimSpace(line)
		if t == "" || strings.HasPrefix(t, "#") {
			continue // comments restate the old header; the new one replaces them
		}
		if limineBrandedKey(t) {
			continue
		}
		kept = append(kept, line)
	}

	header := limineBranding
	if !limineHasBootTree(base) {
		header = strings.Replace(header, "default_entry: 2\n", "default_entry: 1\n", 1)
	}

	var b strings.Builder
	b.WriteString("# Ryoku limine config -- branding globals + generated entries. managed by\n")
	b.WriteString("# limine-mkinitcpio-hook / limine-snapper-sync (entries) and ryoku (globals).\n")
	b.WriteString(header)
	if len(kept) > 0 {
		b.WriteString("\n")
		b.WriteString(strings.Join(kept, "\n"))
		b.WriteString("\n")
	}
	if body != "" {
		b.WriteString("\n")
		b.WriteString(body)
	}
	out := b.String()
	if !strings.HasSuffix(out, "\n") {
		out += "\n"
	}
	return out
}

func limineBrandedKey(trimmedLine string) bool {
	l := strings.ToLower(trimmedLine)
	for _, k := range limineBrandedKeys {
		if strings.HasPrefix(l, k) {
			return true
		}
	}
	return false
}

// splitLimineConf: prelude (global options before the first menu entry) and
// body (the first "/" entry line to EOF, verbatim -- entries, sub-entries,
// their comments and fences).
func splitLimineConf(conf string) (prelude, body string) {
	lines := strings.Split(conf, "\n")
	for i, line := range lines {
		if strings.HasPrefix(line, "/") {
			return strings.Join(lines[:i], "\n"), strings.Join(lines[i:], "\n")
		}
	}
	return conf, ""
}

// staleLimineBootNums: NVRAM boot numbers whose loader is the legacy
// hand-copied \EFI\limine\limine.efi (never \EFI\limine\limine_x64.efi).
// parsed from `efibootmgr` output lines like
//
//	Boot0003* Ryoku HD(1,GPT,...)/\EFI\limine\limine.efi
func staleLimineBootNums(efibootmgr string) []string {
	var nums []string
	for _, line := range strings.Split(efibootmgr, "\n") {
		if !strings.HasPrefix(line, "Boot") || len(line) < 8 {
			continue
		}
		num := line[4:8]
		if !isHex4(num) {
			continue
		}
		if strings.Contains(line, `\limine.efi`) {
			nums = append(nums, num)
		}
	}
	return nums
}

func isHex4(s string) bool {
	if len(s) != 4 {
		return false
	}
	for _, c := range s {
		if !((c >= '0' && c <= '9') || (c >= 'A' && c <= 'F') || (c >= 'a' && c <= 'f')) {
			return false
		}
	}
	return true
}

func efibootmgrOutput() string {
	out, err := exec.Command("efibootmgr").Output()
	if err != nil {
		return ""
	}
	return string(out)
}

// hasRyokuBootEntry: does any active NVRAM entry boot the package-refreshed
// limine? limine-install registers its entry labeled "Limine" with a VenHw
// device path (no file path), while the installer writes a "Ryoku" entry
// loading EFI/limine/limine_x64.efi. Match either, but NOT the legacy
// \limine.efi entry (staleLimineBootNums owns that). pure, so the "do not
// retire the old entry until a replacement exists" guard and the missing-entry
// reconciler are testable without efibootmgr.
func hasRyokuBootEntry(efibootmgr string) bool {
	for _, line := range strings.Split(efibootmgr, "\n") {
		if len(line) < 9 || !strings.HasPrefix(line, "Boot") || !isHex4(line[4:8]) || line[8] != '*' {
			continue // only active boot entries
		}
		if strings.Contains(line, `\limine_x64.efi`) || limineBootLabel(line) == "Limine" {
			return true
		}
	}
	return false
}

// limineBootLabel: the label field of an efibootmgr entry line
// ("Boot0004* Limine\tVenHw(...)" -> "Limine"). efibootmgr separates the label
// from the device path with a tab; fall back to the first field for
// space-separated output. "" when the line is not a boot entry.
func limineBootLabel(line string) string {
	if len(line) < 8 || !isHex4(line[4:8]) {
		return ""
	}
	rest := strings.TrimSpace(strings.TrimPrefix(line[8:], "*"))
	if i := strings.IndexByte(rest, '\t'); i >= 0 {
		return strings.TrimSpace(rest[:i])
	}
	if fields := strings.Fields(rest); len(fields) > 0 {
		return fields[0]
	}
	return ""
}

// parseEspDiskPart derives the efibootmgr --disk (whole device) and --part
// (number) from the ESP mount source, its parent-disk name (lsblk PKNAME), and
// the partition's sysfs number. pure: the wrangling that decides what NVRAM
// entry gets written, tested without real block devices.
func parseEspDiskPart(source, pkname, partition string) (disk, part string, ok bool) {
	source = strings.TrimSpace(source)
	pkname = strings.TrimSpace(pkname)
	part = strings.TrimSpace(partition)
	if !strings.HasPrefix(source, "/dev/") || pkname == "" || part == "" {
		return "", "", false
	}
	return "/dev/" + pkname, part, true
}

// espDiskPart resolves the ESP block device backing /boot into an efibootmgr
// --disk / --part pair.
func espDiskPart() (disk, part string, ok bool) {
	out, err := exec.Command("findmnt", "-n", "-o", "SOURCE", "--target", "/boot").Output()
	if err != nil {
		return "", "", false
	}
	src := strings.TrimSpace(string(out))
	pk, err := exec.Command("lsblk", "-no", "PKNAME", src).Output()
	if err != nil {
		return "", "", false
	}
	partition := readFileSafe("/sys/class/block/" + filepath.Base(src) + "/partition")
	return parseEspDiskPart(src, string(pk), partition)
}

// registerRyokuBootEntry writes the UEFI boot entry the installer writes: a
// "Ryoku" entry loading EFI/limine/limine_x64.efi on the ESP's disk/partition.
func registerRyokuBootEntry() error {
	disk, part, ok := espDiskPart()
	if !ok {
		return fmt.Errorf("could not determine the ESP disk and partition")
	}
	return sys.Run("sudo", "efibootmgr", "--create", "--disk", disk, "--part", part,
		"--label", "Ryoku", "--loader", `\EFI\limine\limine_x64.efi`, "--unicode")
}

// ---- reconciler: limine UEFI boot entry --------------------------------------

// reconcileLimineBootEntry restores a vanished Ryoku UEFI boot entry. When the
// firmware has no NVRAM entry loading the package-refreshed bootloader but the
// binary is on the ESP, the machine has dropped off the boot menu (an earlier
// migrate bug retired the old entry without writing a replacement) and boots
// only via the removable EFI/BOOT fallback, if at all. Re-register the entry
// exactly as the installer does. Idempotent: no-op once an entry loads the
// bootloader, and it stands aside for the layout migration while a legacy entry
// is still there to convert.
func reconcileLimineBootEntry(checkOnly bool) recResult {
	if !sys.PkgInstalled("limine") || !sys.Exists(limineToolEFI) {
		return okRes("not a limine-managed boot on this box")
	}
	if !sys.Has("efibootmgr") {
		return okRes("no efibootmgr to inspect the UEFI boot menu")
	}
	out := efibootmgrOutput()
	if out == "" {
		return okRes("no UEFI boot entries to check")
	}
	if hasRyokuBootEntry(out) {
		return okRes("Ryoku UEFI boot entry present")
	}
	if len(staleLimineBootNums(out)) > 0 {
		return okRes("legacy limine boot entry present; the layout migration owns it")
	}
	fix := `sudo efibootmgr --create --disk <ESP disk> --part <ESP part> --label Ryoku --loader '\EFI\limine\limine_x64.efi' --unicode`
	if checkOnly {
		return wouldRes("no UEFI boot entry loads the Ryoku bootloader; the boot option is missing from firmware").
			withFix(fix)
	}
	if err := registerRyokuBootEntry(); err != nil {
		return failRes("the Ryoku UEFI boot entry is missing and could not be re-registered: %v", err).
			withFix(fix)
	}
	return fixedRes("re-registered the missing Ryoku UEFI boot entry")
}

// writeBootFile: stage + `sudo cp` (not install -o/-g: the ESP is vfat, which
// has no owners to set and rejects chown).
func writeBootFile(path, contents string) error {
	tmp, err := os.CreateTemp("", "ryoku-limine-*")
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
	return sys.Run("sudo", "cp", tmp.Name(), path)
}

// ---- reconciler: limine snapshot-sync OS name --------------------------------

// reconcileLimineOSName aligns TARGET_OS_NAME in /etc/default/limine with the
// name of the actual Ryoku boot entry in /boot/limine.conf, so limine-snapper-sync
// can find it to hang the Snapshots submenu under. the healthy menu is the
// "/+Ryoku" UKI tree (name "Ryoku") that limine-mkinitcpio-hook generates, and the
// shipped default already matches it -- a no-op. but a box still on the flat
// "/Ryoku Linux" fallback entry needs that name instead, and the mismatch fails
// limine-snapper-sync on every snapper-cleanup (its ExecStopPost), so the boot
// menu never lists a rollback snapshot. read the real entry name and converge to
// it, then clear the stale failed state. never invents a name: no Ryoku entry
// found -> leave it alone.
// ---- reconciler: limine UKI boot tree ------------------------------------------

// reconcileLimineUKITree converges a limine box onto the hook-owned boot menu
// the design always intended: /etc/default/limine ships with ENABLE_UKI=yes
// and aur.packages carries limine-mkinitcpio-hook, but boxes installed before
// (or without) the AUR step run on the flat "/Ryoku Linux" placeholder
// forever. limine-snapper-sync refuses to hang the Snapshots submenu under an
// entry with no "//<kernel>" sub-entries, so those boxes never see a rollback
// in the boot menu at all; omarchy works because its installer hard-requires
// the hook and fails the install when no "/+" tree appears. Install the hook
// (its deploy hook builds the UKIs and regenerates the entries), drop the
// flat placeholder the way the installer's finalize does, and run one sync so
// the snapshots show up now, not at the next snapper event.
func reconcileLimineUKITree(checkOnly bool) recResult {
	if !sys.PkgInstalled("limine") {
		return okRes("not a limine-managed boot on this box")
	}
	defaults := readFileSafe("/etc/default/limine")
	if !strings.Contains(defaults, "ENABLE_UKI=yes") {
		return okRes("limine box without the UKI design (no ENABLE_UKI); nothing to converge")
	}
	conf := readFileSafe(limineESPConf)
	if conf == "" {
		return okRes("no readable %s; the layout reconciler owns that", limineESPConf)
	}
	hookMissing := !sys.PkgInstalled("limine-mkinitcpio-hook")
	_, hasFlat := limineDropFlat(conf)
	if !hookMissing && limineHasUKITree(conf) && !hasFlat {
		return okRes("limine-mkinitcpio-hook owns the boot menu (UKI tree with kernel sub-entries)")
	}
	if checkOnly {
		return wouldRes("the boot menu is still the flat install placeholder, so limine-snapper-sync cannot add the Snapshots submenu (rollbacks never appear at boot)").
			withFix("ryoku doctor installs limine-mkinitcpio-hook and promotes the menu to the /+Ryoku UKI tree")
	}
	var done []string
	if hookMissing {
		if err := sys.Run("ryoku-pkg-aur-add", "limine-mkinitcpio-hook"); err != nil {
			return failRes("could not install limine-mkinitcpio-hook: %v", err).
				withFix("ryoku-pkg-aur-add limine-mkinitcpio-hook, then sudo ryoku doctor")
		}
		done = append(done, "installed limine-mkinitcpio-hook")
	}
	// the install's deploy hook normally regenerates the menu; if the tree is
	// still absent (hook was present but never ran), ask for it explicitly.
	if !limineHasUKITree(readFileSafe(limineESPConf)) && sys.Has("limine-update") {
		if err := sys.Sudo("limine-update"); err != nil {
			return failRes("limine-update could not build the UKI boot tree: %v", err).
				withFix("sudo limine-update, then sudo ryoku doctor")
		}
		done = append(done, "rebuilt the boot menu with limine-update")
	}
	conf = readFileSafe(limineESPConf)
	if !limineHasUKITree(conf) {
		return failRes("no UKI kernel entries in %s even after limine-update; snapshots cannot attach", limineESPConf)
	}
	// mirror the installer's finalize: with a standalone tree the flat
	// placeholder is clutter; either way a directory can't autoboot, so
	// default_entry moves to the newest UKI inside it.
	if promoted, changed := limineDropFlat(conf); changed {
		if err := writeRootFile(limineESPConf, promoted, "0644"); err != nil {
			return failRes("could not promote the boot menu in %s: %v", limineESPConf, err)
		}
		done = append(done, "promoted the menu default onto the UKI tree")
	}
	if sys.Has("limine-snapper-sync") {
		if err := sys.Sudo("limine-snapper-sync"); err == nil {
			done = append(done, "synced the Snapshots submenu")
		}
	}
	return fixedRes("boot menu converged onto the UKI tree: %s; rollback snapshots now appear at boot", strings.Join(done, "; "))
}

// limineHasUKITree: does the config carry tool-generated kernel sub-entries.
// older limine-entry-tool writes a standalone "/+Name" expanded tree; 1.37+
// adopts the installer's flat entry as the tree root and nests indented
// "//<kernel>" children under it. either shape satisfies limine-snapper-sync.
func limineHasUKITree(conf string) bool {
	for _, l := range strings.Split(conf, "\n") {
		if strings.HasPrefix(l, "/+") {
			return true
		}
		if t := strings.TrimLeft(l, " \t"); strings.HasPrefix(t, "//") {
			return true
		}
	}
	return false
}

// limineDropFlat promotes the menu past the install placeholder, mirroring the
// installer's finalize. with a standalone "/+" tree the flat "/Ryoku Linux..."
// entries (entry line plus indented options) are clutter and go; in the
// adopted layout the placeholder IS the tree root, so entries stay untouched.
// either way default_entry: 1 points at a directory that can't autoboot and
// moves to 2 (the first UKI inside). pure, so it is unit-testable;
// changed=false when there is nothing to do.
func limineDropFlat(conf string) (string, bool) {
	dropFlat := false
	for _, l := range strings.Split(conf, "\n") {
		if strings.HasPrefix(l, "/+") {
			dropFlat = true
			break
		}
	}
	var out []string
	skip, changed := false, false
	for _, l := range strings.Split(conf, "\n") {
		if dropFlat && strings.HasPrefix(l, "/Ryoku Linux") {
			skip, changed = true, true
			continue
		}
		if skip && strings.TrimSpace(l) != "" && (strings.HasPrefix(l, " ") || strings.HasPrefix(l, "\t")) {
			continue
		}
		skip = false
		if l == "default_entry: 1" {
			out = append(out, "default_entry: 2")
			changed = true
			continue
		}
		out = append(out, l)
	}
	return strings.Join(out, "\n"), changed
}

func reconcileLimineOSName(checkOnly bool) recResult {
	const path = "/etc/default/limine"
	cur := readFileSafe(path)
	if cur == "" {
		return okRes("no /etc/default/limine (limine snapshot sync not in use)")
	}
	got, ok := limineOSNameValue(cur)
	if !ok {
		return okRes("limine config sets no TARGET_OS_NAME")
	}
	want := limineEntryName(readFileSafe("/boot/limine.conf"))
	if want == "" {
		return okRes("no Ryoku boot entry found to match TARGET_OS_NAME against")
	}
	if got == want {
		return okRes("limine snapshot entries sync under %q", want)
	}
	if checkOnly {
		return wouldRes("TARGET_OS_NAME %q does not match the boot entry %q, so limine-snapper-sync fails snapper-cleanup", got, want).
			withFix("ryoku doctor sets TARGET_OS_NAME to %q", want)
	}
	if err := writeRootFile(path, setLimineOSName(cur, want), "0644"); err != nil {
		return failRes("could not update %s: %v", path, err)
	}
	// the unit is likely still sitting failed from earlier runs; clear it so the
	// failed-services check reads clean this same pass. best-effort.
	_ = exec.Command("sudo", "-n", "systemctl", "reset-failed", "snapper-cleanup.service").Run()
	return fixedRes("set TARGET_OS_NAME to %q to match the boot entry so snapshots sync", want)
}

// limineEntryName: the name of the primary Ryoku OS entry in a /boot/limine.conf.
// the expanded UKI tree ("/+Ryoku" -> "Ryoku") wins over the flat fallback
// ("/Ryoku Linux" -> "Ryoku Linux") when both are present, so a healthy box that
// still carries a stray flat placeholder is never re-pointed off its real entry.
// top-level entries only ("/name" or "/+name", not a "//" sub-entry); "" when no
// Ryoku entry is found.
func limineEntryName(conf string) string {
	var flat string
	for _, l := range strings.Split(conf, "\n") {
		t := strings.TrimRight(l, " \t\r")
		if !strings.HasPrefix(t, "/") || strings.HasPrefix(t, "//") {
			continue
		}
		expanded := strings.HasPrefix(t, "/+")
		name := strings.TrimPrefix(strings.TrimPrefix(t, "/"), "+")
		if !strings.HasPrefix(name, "Ryoku") {
			continue
		}
		if expanded {
			return name
		}
		if flat == "" {
			flat = name
		}
	}
	return flat
}

// limineOSNameValue pulls the TARGET_OS_NAME value out of an /etc/default/limine,
// quotes stripped. ok=false when there is no such assignment.
func limineOSNameValue(conf string) (string, bool) {
	for _, l := range strings.Split(conf, "\n") {
		t := strings.TrimSpace(l)
		if strings.HasPrefix(t, "#") || !strings.HasPrefix(t, "TARGET_OS_NAME") {
			continue
		}
		if eq := strings.IndexByte(t, '='); eq >= 0 {
			return strings.Trim(strings.TrimSpace(t[eq+1:]), "\"'"), true
		}
	}
	return "", false
}

// setLimineOSName rewrites the TARGET_OS_NAME assignment to name, every other
// line preserved verbatim.
func setLimineOSName(conf, name string) string {
	lines := strings.Split(conf, "\n")
	for i, l := range lines {
		t := strings.TrimSpace(l)
		if strings.HasPrefix(t, "#") || !strings.HasPrefix(t, "TARGET_OS_NAME") {
			continue
		}
		if strings.IndexByte(t, '=') >= 0 {
			lines[i] = fmt.Sprintf("TARGET_OS_NAME=%q", name)
		}
	}
	return strings.Join(lines, "\n")
}
