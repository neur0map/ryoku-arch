package main

import (
	"strings"
	"testing"
)

func segByMount(segs []part, mount string) (part, bool) {
	for _, s := range segs {
		if s.mount == mount {
			return s, true
		}
	}
	return part{}, false
}

func segByFS(segs []part, fs string) (part, bool) {
	for _, s := range segs {
		if s.fs == fs {
			return s, true
		}
	}
	return part{}, false
}

// root = everything past the ESP, swapfile carved out of it. so usable root
// shrinks by exactly the swap size and no "free" segment appears (backend
// always gives root 100% of the remaining space).
func TestRootCarvesSwap(t *testing.T) {
	m := model{diskG: 1000, espG: 1, swapG: 16}
	if got := m.availRoot(); got != 999 {
		t.Fatalf("availRoot = %d, want 999", got)
	}
	root, ok := segByMount(m.layoutSegs(), "/")
	if !ok || root.size != 983 {
		t.Fatalf("root usable = %d (ok=%v), want 983 (999 - 16 swap)", root.size, ok)
	}
	if sw, ok := segByFS(m.layoutSegs(), "swap"); !ok || sw.size != 16 {
		t.Fatalf("swap segment = %d (ok=%v), want 16", sw.size, ok)
	}
	for _, s := range m.layoutSegs() {
		if s.status == "free" {
			t.Fatalf("unexpected free segment %+v", s)
		}
	}
}

// the reported bug: bumping swap must reduce the usable total.
func TestSwapReducesRoot(t *testing.T) {
	m := model{diskG: 1000, espG: 1, swapG: 16}
	before, _ := segByMount(m.layoutSegs(), "/")
	m.swapG = 32
	after, _ := segByMount(m.layoutSegs(), "/")
	if after.size >= before.size {
		t.Fatalf("root did not shrink when swap grew: %d -> %d", before.size, after.size)
	}
	if after.size != 967 {
		t.Fatalf("root = %d, want 967 (999 - 32)", after.size)
	}
}

// swapG=0 -> no swapfile, no swap segment, root eats the whole rest.
func TestNoSwapNoSegment(t *testing.T) {
	m := model{diskG: 1000, espG: 1, swapG: 0}
	if _, ok := segByFS(m.layoutSegs(), "swap"); ok {
		t.Fatal("swap segment present with swapG=0")
	}
	root, _ := segByMount(m.layoutSegs(), "/")
	if root.size != 999 {
		t.Fatalf("root = %d, want 999", root.size)
	}
}

func TestSwapCeil(t *testing.T) {
	if got := (model{diskG: 1000, espG: 1}).swapCeil(); got != 64 {
		t.Fatalf("swapCeil big disk = %d, want 64", got)
	}
	if got := (model{diskG: 40, espG: 1}).swapCeil(); got != 39-minRootGiB {
		t.Fatalf("swapCeil small disk = %d, want %d (avail 39 - %d root floor)", got, 39-minRootGiB, minRootGiB)
	}
	if got := (model{diskG: 8, espG: 1}).swapCeil(); got != 0 {
		t.Fatalf("swapCeil tiny disk = %d, want 0 (never negative)", got)
	}
}

// growing ESP eats from the same pool, so an out-of-range swap gets clamped back.
func TestESPBumpClampsSwap(t *testing.T) {
	m := model{diskG: 40, espG: 1, swapG: 30}
	m.setRow("esp", 4) // availRoot 40-4=36 -> swapCeil 36-20=16
	if m.swapG != 16 {
		t.Fatalf("swap after esp bump = %d, want 16", m.swapG)
	}
}

// alongsideModel: a dual-boot layout on a 256 GiB disk with the given free
// region. The kept partitions model a real Windows install (its ESP + an NTFS
// data partition). Alongside carves a fixed 2 GiB XBOOTLDR /boot inside the free
// region (Windows' ESP is shared, not counted), so readiness/sizing depend on
// the free region and alongsideBootGiB, never on espG or the kept Windows ESP.
func alongsideModel(freeG, swapG int) model {
	return model{
		// a real dual-boot disk is GPT; the GPT-only guard is exercised separately.
		picks: map[string]string{"disk": "alongside"}, gpt: true, diskG: 256, freeG: freeG, espG: 1, swapG: swapG,
		kept: []part{
			{dev: "EFI (Windows)", size: 1, fs: "fat32", mount: "-", flags: "esp", status: "keep"},
			{dev: "Windows (NTFS)", size: 120, fs: "ntfs", mount: "Windows", flags: "-", status: "keep"},
		},
	}
}

// alongside drops root into the detected free region and carves a fixed 2 GiB
// XBOOTLDR /boot from that region (never the Windows ESP), so usable root =
// free - 2 GiB boot - swap.
func TestAlongsideRootUsesFreeSpace(t *testing.T) {
	m := alongsideModel(100, 16)
	if got := m.availRoot(); got != 98 {
		t.Fatalf("availRoot = %d, want 98 (100 free - 2 boot)", got)
	}
	root, ok := segByMount(m.layoutSegs(), "/")
	if !ok || root.size != 82 {
		t.Fatalf("root usable = %d (ok=%v), want 82 (98 - 16 swap)", root.size, ok)
	}
	// A fresh 2 GiB boot partition for OUR install must exist in the free region.
	var newBoot bool
	for _, s := range m.layoutSegs() {
		if s.status == "new" && strings.Contains(s.flags, "esp") {
			newBoot = true
			if s.size != alongsideBootGiB {
				t.Fatalf("new boot size = %d, want %d", s.size, alongsideBootGiB)
			}
		}
	}
	if !newBoot {
		t.Fatal("alongside must create its own boot partition in the free region, never reuse Windows' ESP")
	}
	// The kept Windows ESP must be mounted nowhere (never /boot), so pacstrap /
	// mkinitcpio can never fill and clobber it.
	if _, boot := segByMount(m.kept, "/boot"); boot {
		t.Fatal("a kept partition is mounted at /boot; the Windows ESP must never be reused")
	}
}

// alongside is allowed once the free region holds our 2 GiB boot plus the root
// floor (minRootGiB + alongsideBootGiB), so the TUI never hands the backend a
// layout it'd reject.
func TestAlongsidePartReady(t *testing.T) {
	need := minRootGiB + alongsideBootGiB
	if !alongsideModel(need, 0).partReady() {
		t.Fatalf("alongside with exactly %dG free should be ready", need)
	}
	if alongsideModel(need-1, 0).partReady() {
		t.Fatalf("alongside with %dG free (< %d) must not be ready", need-1, need)
	}
	if !alongsideModel(200, 0).partReady() {
		t.Fatal("alongside with a roomy free region should be ready")
	}
}

// swapCeil leaves minRootGiB of root after the boot partition for BOTH
// strategies; alongside works off the free region (freeG - alongsideBootGiB).
func TestAlongsideSwapCeil(t *testing.T) {
	if got := alongsideModel(40, 0).swapCeil(); got != 40-alongsideBootGiB-minRootGiB {
		t.Fatalf("alongside swapCeil = %d, want %d (40 free - %d boot - %d root)", got, 40-alongsideBootGiB-minRootGiB, alongsideBootGiB, minRootGiB)
	}
}

// regression for the alongside install that died mid-run: the free-space gate
// must account for OUR boot partition and the root floor plus the swapfile, and
// swap must be clamped on load so a fat default never over-promises. Invariant
// after clamp: minRootGiB + swap <= availRoot (= freeG - alongsideBootGiB).
func TestAlongsideSwapClampMatchesBackend(t *testing.T) {
	// tight region: 25G free leaves availRoot 23; the 16G default can't coexist
	// with the 20G root floor, so clamp pins swap to 23-20=3 and Tab stays open.
	tight := alongsideModel(25, 16)
	tight.clampSwapToLayout()
	if tight.swapG != 3 {
		t.Fatalf("tight swapG = %d, want 3 (availRoot 23 - %d root)", tight.swapG, minRootGiB)
	}
	if minRootGiB+tight.swapG > tight.availRoot() {
		t.Fatalf("tight over-promises backend: %d + %d > %d availRoot", minRootGiB, tight.swapG, tight.availRoot())
	}
	if !tight.partReady() {
		t.Fatal("tight but installable region must stay Tab-ready after clamp")
	}

	// roomy region: 200G free comfortably holds root + the 16G default, so clamp
	// must leave the default swap untouched (no over-shrink).
	roomy := alongsideModel(200, 16)
	roomy.clampSwapToLayout()
	if roomy.swapG != 16 {
		t.Fatalf("roomy swapG = %d, want 16 (default preserved)", roomy.swapG)
	}

	// the invariant holds across the whole installable range: once freeG clears
	// the boot + root floor, root + swap always fits the free region after clamp.
	for _, freeG := range []int{minRootGiB + alongsideBootGiB, minRootGiB + alongsideBootGiB + 1, 25, 40, 200} {
		m := alongsideModel(freeG, 16)
		m.clampSwapToLayout()
		if minRootGiB+m.swapG > m.availRoot() {
			t.Fatalf("freeG=%d: %d + %d swap > %d availRoot after clamp", freeG, minRootGiB, m.swapG, m.availRoot())
		}
	}
}

// envHas: does installEnv carry an exact NAME=VALUE line. the strategy is a
// literal contract with the backend; loose substring matching would let
// "RYOKU_DISK_STRATEGY=" match "RYOKU_DISK_STRATEGY=whole".
func envHas(env []string, want string) bool {
	for _, e := range env {
		if e == want {
			return true
		}
	}
	return false
}

// envValue: value of an exact NAME=, or ("",false) when missing. the distinction
// matters: when the TUI never recorded a pick, the backend MUST see NAME with
// an empty value (so it fails closed). that's a different state from the key
// being absent.
func envValue(env []string, name string) (string, bool) {
	prefix := name + "="
	for _, e := range env {
		if len(e) >= len(prefix) && e[:len(prefix)] == prefix {
			return e[len(prefix):], true
		}
	}
	return "", false
}

// regression for the dual-boot data-loss bug: alongside must reach the backend
// verbatim. an older installEnv defaulted picks["disk"] to "whole", silently
// wiping the disk when the pick was set but somehow not emitted. assert the
// pick survives end to end.
func TestAlongsidePickReachesEnv(t *testing.T) {
	m := alongsideModel(100, 16)
	env := m.installEnv()
	if !envHas(env, "RYOKU_DISK_STRATEGY=alongside") {
		t.Fatalf("alongside pick lost: env = %v", env)
	}
	if envHas(env, "RYOKU_DISK_STRATEGY=whole") {
		t.Fatalf("alongside pick was silently turned into whole: %v", env)
	}
}

// regression for the fail-OPEN default that ate user data: when no
// disk-strategy pick exists, env MUST carry the variable with an empty value
// so the backend's required-strategy guard aborts. defaulting to "whole" here
// was the silent wipe.
func TestEmptyDiskStrategyDoesNotDefaultToWhole(t *testing.T) {
	m := model{picks: map[string]string{}}
	env := m.installEnv()
	if envHas(env, "RYOKU_DISK_STRATEGY=whole") {
		t.Fatalf("empty pick was silently turned into whole; env = %v", env)
	}
	v, ok := envValue(env, "RYOKU_DISK_STRATEGY")
	if !ok {
		t.Fatal("RYOKU_DISK_STRATEGY missing from env; backend cannot fail closed without it")
	}
	if v != "" {
		t.Fatalf("empty pick must surface as empty value (got %q) so backend aborts", v)
	}
}

// explicit whole must also reach the backend verbatim, so users who actually
// want a wipe still get one.
func TestWholePickReachesEnv(t *testing.T) {
	m := model{picks: map[string]string{"disk": "whole"}}
	env := m.installEnv()
	if !envHas(env, "RYOKU_DISK_STRATEGY=whole") {
		t.Fatalf("whole pick lost: env = %v", env)
	}
}

// partReady must refuse to advance past partitions with no disk strategy
// committed. it used to return true for "whole" OR any non-alongside value
// (including empty), so an uncommitted strategy slipped straight into Review
// and on to the backend.
func TestPartReadyRequiresCommittedStrategy(t *testing.T) {
	m := model{picks: map[string]string{}, diskG: 256}
	if m.partReady() {
		t.Fatal("partReady true for empty disk strategy; must require an explicit pick")
	}
	m.picks["disk"] = "bogus"
	if m.partReady() {
		t.Fatalf("partReady true for unknown strategy %q; must reject", m.picks["disk"])
	}
	m.picks["disk"] = "whole"
	if !m.partReady() {
		t.Fatal("partReady false for whole on a large enough disk; must allow")
	}
}

// A blocked partition step must say WHY, so Tab never dies silently. Alongside is
// blocked when the free region can't hold our ESP plus the root floor.
func TestPartBlockReasonExplainsBlockedTab(t *testing.T) {
	m := model{picks: map[string]string{"disk": "alongside"}, gpt: true, diskG: 256, freeG: 5, espG: 1}
	if r := m.partBlockReason(); r == "" {
		t.Fatal("partBlockReason empty for alongside with too little free space; Tab would die silently")
	}
	m.freeG = 200
	if r := m.partBlockReason(); r != "" {
		t.Fatalf("partBlockReason %q for alongside with 200G free; want none", r)
	}
	m = model{picks: map[string]string{"disk": "whole"}, diskG: 256}
	if r := m.partBlockReason(); r != "" {
		t.Fatalf("partBlockReason %q for a valid whole-disk layout; want none", r)
	}
	if !m.partReady() {
		t.Fatal("partReady false while partBlockReason is empty; they must agree")
	}
}

// disk-strategy picker pre-selects items[0], so a quick Enter commits the
// first item. The invariant is "a fast Enter never wipes anything that
// exists": on a populated disk alongside leads (non-destructive), and it only
// says "Windows" when an NTFS install is really there; a blank disk has
// nothing to protect, so it gets the single whole-disk path with wording that
// doesn't threaten to erase what isn't there.
func TestDiskStrategiesMatchTheDisk(t *testing.T) {
	// blank disk: one honest option, no "keep Windows" fiction.
	blank := diskStrategiesFor(diskLayout{})
	if len(blank) != 1 || blank[0].key != "whole" {
		t.Fatalf("blank disk should offer only whole, got %+v", blank)
	}
	if strings.Contains(blank[0].label+blank[0].hint, "Windows") ||
		strings.Contains(strings.ToLower(blank[0].label+blank[0].hint), "erase") {
		t.Fatalf("blank-disk wording must not mention Windows or erasing: %+v", blank[0])
	}

	// populated non-Windows disk: alongside leads, without naming Windows.
	pop := diskStrategiesFor(diskLayout{parts: []part{{dev: "/dev/vda1"}}})
	if len(pop) < 2 || pop[0].key != "alongside" {
		t.Fatalf("populated disk should lead with alongside, got %+v", pop)
	}
	if strings.Contains(pop[0].label, "Windows") {
		t.Fatalf("non-Windows disk must not promise to keep Windows: %+v", pop[0])
	}

	// Windows disk: alongside leads and says so.
	win := diskStrategiesFor(diskLayout{parts: []part{{dev: "/dev/vda1"}}, windows: true})
	if len(win) < 2 || win[0].key != "alongside" || !strings.Contains(win[0].label, "Windows") {
		t.Fatalf("windows disk should lead with alongside-Windows, got %+v", win)
	}
}

// whole on a populated disk must NOT emit RYOKU_WIPE_CONFIRMED until the user
// has typed "ERASE" and hit enter on Review (wipeStage 0 -> 1 -> 2). with no
// ack the env carries the empty token and ryoku_partition_whole aborts before
// any sgdisk runs.
func TestWholePopulatedWithoutConfirmEnvLacksToken(t *testing.T) {
	m := model{
		picks:    map[string]string{"disk": "whole"},
		existing: []part{{dev: "/dev/vda1", size: 1}, {dev: "/dev/vda2", size: 200}},
	}
	env := m.installEnv()
	if envHas(env, "RYOKU_WIPE_CONFIRMED=1") {
		t.Fatalf("RYOKU_WIPE_CONFIRMED=1 emitted before the user typed ERASE: %v", env)
	}
}

// once the user typed ERASE and wipeStage hit 2, env must carry
// RYOKU_WIPE_CONFIRMED=1 so the backend proceeds.
func TestWholePopulatedAfterConfirmEnvHasToken(t *testing.T) {
	m := model{
		picks:     map[string]string{"disk": "whole"},
		existing:  []part{{dev: "/dev/vda1", size: 1}},
		wipeStage: 2,
	}
	if !envHas(m.installEnv(), "RYOKU_WIPE_CONFIRMED=1") {
		t.Fatalf("RYOKU_WIPE_CONFIRMED=1 missing after typed-ERASE confirm")
	}
}

// blank disk + whole + no confirm must NOT emit RYOKU_WIPE_CONFIRMED. backend
// doesn't require the token on a blank disk, and the TUI must not fabricate
// one either.
func TestWholeBlankEnvOmitsToken(t *testing.T) {
	m := model{picks: map[string]string{"disk": "whole"}}
	if envHas(m.installEnv(), "RYOKU_WIPE_CONFIRMED=1") {
		t.Fatal("RYOKU_WIPE_CONFIRMED=1 emitted on a blank disk without explicit confirm")
	}
}

// diskPopulated = len(existing) > 0; the wipe gate keys off this.
func TestDiskPopulatedReflectsExisting(t *testing.T) {
	if (model{}).diskPopulated() {
		t.Fatal("diskPopulated true on a model with no existing partitions")
	}
	if !(model{existing: []part{{dev: "/dev/vda1"}}}).diskPopulated() {
		t.Fatal("diskPopulated false on a model with one existing partition")
	}
}

// the typed ack is checked case-insensitively against "ERASE"; drives the
// Review onKey handler.
func TestEraseInputAccepts(t *testing.T) {
	// EqualFold matches "ERASE" / "erase" / "Erase", nothing else.
	for _, ok := range []string{"ERASE", "erase", "Erase"} {
		if !strings.EqualFold(ok, "ERASE") {
			t.Fatalf("strings.EqualFold(%q,\"ERASE\") should accept", ok)
		}
	}
	for _, bad := range []string{"", "ERAS", "ERASED", "DELETE"} {
		if strings.EqualFold(bad, "ERASE") {
			t.Fatalf("strings.EqualFold(%q,\"ERASE\") must reject", bad)
		}
	}
}

// reviewWipeModel: model parked on Review with whole + populated disk, the
// state where the typed-confirm gate fires.
func reviewWipeModel() model {
	flow := steps()
	m := model{
		flow:      flow,
		picks:     map[string]string{"disk": "whole"},
		existing:  []part{{dev: "/dev/vda1"}, {dev: "/dev/vda2"}},
		yes:       true,
		netOnline: true, // an online machine: the wipe gate is about ERASE, not connectivity
	}
	for i, st := range flow {
		if st.key == "review" {
			m.idx = i
			break
		}
	}
	return m
}

// Enter on Yes for whole+populated must NOT start install. it advances into the
// typed-confirm sub-stage; the actual install handoff is gated on the user
// typing "ERASE".
func TestReviewWipeGateEntersConfirmStage(t *testing.T) {
	m := reviewWipeModel()
	nm, cmd := m.onKey("enter")
	if cmd != nil {
		t.Fatal("Enter started install before the ERASE acknowledgement")
	}
	n := nm.(model)
	if n.wipeStage != 1 {
		t.Fatalf("wipeStage = %d, want 1 (typing prompt active)", n.wipeStage)
	}
	if n.eraseInput != "" {
		t.Fatalf("eraseInput = %q, want empty on stage entry", n.eraseInput)
	}
}

// every keystroke during typed-confirm extends eraseInput; nothing else (Y/N
// toggle, jump-to-step digit handler) fires while typing.
func TestReviewWipeGateAcceptsEraseTyping(t *testing.T) {
	m := reviewWipeModel()
	m.wipeStage = 1
	for _, k := range []string{"E", "R", "A", "S", "E"} {
		nm, _ := m.onKey(k)
		m = nm.(model)
	}
	if m.eraseInput != "ERASE" {
		t.Fatalf("eraseInput = %q, want \"ERASE\"", m.eraseInput)
	}
	if m.wipeStage != 1 {
		t.Fatalf("wipeStage = %d, want 1 until Enter", m.wipeStage)
	}
	if m.yes != true {
		t.Fatal("typed-confirm leaked into Y/N toggle")
	}
}

// Esc cancels the typed-confirm sub-stage, back to normal Y/N view.
func TestReviewWipeGateEscCancels(t *testing.T) {
	m := reviewWipeModel()
	m.wipeStage, m.eraseInput = 1, "ERA"
	nm, _ := m.onKey("esc")
	n := nm.(model)
	if n.wipeStage != 0 {
		t.Fatalf("wipeStage = %d after esc, want 0", n.wipeStage)
	}
	if n.eraseInput != "" {
		t.Fatalf("eraseInput = %q after esc, want empty", n.eraseInput)
	}
}

// bare Enter with the wrong word stays in stage 1; only the exact "ERASE"
// (case-insensitive) ack advances to stage 2.
func TestReviewWipeGateEnterWithoutEraseDoesNotLaunch(t *testing.T) {
	m := reviewWipeModel()
	m.wipeStage, m.eraseInput = 1, "DELETE"
	nm, cmd := m.onKey("enter")
	if cmd != nil {
		t.Fatal("install launched with eraseInput=\"DELETE\"; must require ERASE")
	}
	n := nm.(model)
	if n.wipeStage != 1 {
		t.Fatalf("wipeStage = %d, want 1 (still typing)", n.wipeStage)
	}
}

// alongside no longer shows the ESP-size row: its boot partition is a fixed 2
// GiB XBOOTLDR carved in the free region, so there is nothing to size. Whole
// still exposes the ESP-size control.
func TestAlongsideLayoutHasNoESPRow(t *testing.T) {
	along := alongsideModel(100, 16)
	for _, r := range along.layoutRows() {
		if r.kind == "size" && r.key == "esp" {
			t.Fatal("alongside must not show an ESP-size row; its boot partition is a fixed 2 GiB XBOOTLDR")
		}
	}
	whole := model{picks: map[string]string{"disk": "whole"}, diskG: 256, espG: 1}
	var espRow bool
	for _, r := range whole.layoutRows() {
		if r.kind == "size" && r.key == "esp" {
			espRow = true
		}
	}
	if !espRow {
		t.Fatal("whole must still show the ESP-size row")
	}
}

// swapCeil uses the same minRootGiB floor for whole and alongside (the old 8/15
// split is gone): identical usable space must yield an identical ceiling. Whole's
// ESP is sized to 2 here to match alongside's fixed 2 GiB XBOOTLDR boot.
func TestSwapCeilFloorBothStrategies(t *testing.T) {
	whole := model{picks: map[string]string{"disk": "whole"}, diskG: 40, espG: alongsideBootGiB}
	along := alongsideModel(40, 0)
	if whole.availRoot() != along.availRoot() {
		t.Fatalf("availRoot differs: whole %d vs alongside %d", whole.availRoot(), along.availRoot())
	}
	if whole.swapCeil() != along.swapCeil() {
		t.Fatalf("swapCeil differs across strategies: whole %d vs alongside %d", whole.swapCeil(), along.swapCeil())
	}
	if got := whole.swapCeil(); got != 40-alongsideBootGiB-minRootGiB {
		t.Fatalf("swapCeil = %d, want %d (40 - %d boot - %d floor)", got, 40-alongsideBootGiB-minRootGiB, alongsideBootGiB, minRootGiB)
	}
}

// installs are online-only: RYOKU_ONLINE=1 must always reach the backend.
func TestEnvAlwaysOnline(t *testing.T) {
	m := model{picks: map[string]string{"disk": "whole"}}
	if !envHas(m.installEnv(), "RYOKU_ONLINE=1") {
		t.Fatalf("RYOKU_ONLINE=1 missing from env: %v", m.installEnv())
	}
}

// RYOKU_WIPE_CONFIRMED is emitted only at wipeStage 2 (typed-ERASE confirmed),
// never at stage 0 or 1, so a half-finished confirm can't authorize a wipe.
func TestEnvWipeConfirmedOnlyAtStage2(t *testing.T) {
	for _, c := range []struct {
		stage int
		want  bool
	}{{0, false}, {1, false}, {2, true}} {
		m := model{picks: map[string]string{"disk": "whole"}, existing: []part{{dev: "/dev/vda1"}}, wipeStage: c.stage}
		if got := envHas(m.installEnv(), "RYOKU_WIPE_CONFIRMED=1"); got != c.want {
			t.Fatalf("wipeStage %d: RYOKU_WIPE_CONFIRMED present=%v, want %v", c.stage, got, c.want)
		}
	}
}

// suggestProfile is the pure core of detectHardware's decision: a VM wins first,
// then NVIDIA over the CPU vendor, then AMD, then Intel, else the vm fallback.
func TestSuggestProfile(t *testing.T) {
	for _, c := range []struct {
		name                     string
		isVM, nvidia, amd, intel bool
		want                     string
	}{
		{"vm beats everything", true, true, true, true, "vm"},
		{"nvidia dGPU on amd cpu", false, true, true, false, "amd-nvidia"},
		{"nvidia dGPU on intel cpu", false, true, false, true, "amd-nvidia"},
		{"amd only", false, false, true, false, "amd"},
		{"intel only", false, false, false, true, "intel"},
		{"nothing classifiable", false, false, false, false, "vm"},
	} {
		if got := suggestProfile(c.isVM, c.nvidia, c.amd, c.intel); got != c.want {
			t.Fatalf("%s: suggestProfile = %q, want %q", c.name, got, c.want)
		}
	}
}

// excludeDisk is the pure live-medium/pseudo-device filter behind sysDisks. The
// disk backing the live ISO (live) is hidden so the installer never erases the
// stick it booted from; pseudo devices and eMMC boot/rpmb areas are hidden too.
func TestExcludeDisk(t *testing.T) {
	const live = "/dev/sda"
	for _, c := range []struct {
		name, dev, size string
		want            bool
	}{
		{"real nvme", "/dev/nvme0n1", "512G", false},
		{"live boot medium", live, "32G", true},
		{"zram", "/dev/zram0", "8G", true},
		{"optical", "/dev/sr0", "1024M", true},
		{"loop", "/dev/loop0", "2G", true},
		{"nbd", "/dev/nbd0", "10G", true},
		{"zero size", "/dev/sdb", "0B", true},
		{"empty size", "/dev/sdb", "", true},
		{"emmc boot0", "/dev/mmcblk0boot0", "4M", true},
		{"emmc rpmb", "/dev/mmcblk0rpmb", "4M", true},
		{"emmc user area", "/dev/mmcblk0", "64G", false},
	} {
		if got := excludeDisk(c.dev, c.size, live); got != c.want {
			t.Fatalf("%s: excludeDisk(%q,%q) = %v, want %v", c.name, c.dev, c.size, got, c.want)
		}
	}
	// off-ISO (live == "") nothing is filtered as a live medium.
	if excludeDisk("/dev/sda", "32G", "") {
		t.Fatal("off-ISO (live=\"\"), a normal disk must not be excluded")
	}
}

// bottomDisk resolves a layered boot medium to the physical disk it is built on
// (the inverse `lsblk -s` tree). Direct-flash is a partition on a disk; Ventoy
// interposes a device-mapper node; both must land on the whole disk so sysDisks
// hides the stick we booted from. A loop with no disk under it yields "".
func TestBottomDisk(t *testing.T) {
	for _, c := range []struct {
		name, tree, want string
	}{
		{"direct-flash partition", "/dev/sda1 part\n/dev/sda disk\n", "/dev/sda"},
		{"ventoy device-mapper", "/dev/mapper/ventoy1 dm\n/dev/sda1 part\n/dev/sda disk\n", "/dev/sda"},
		{"loop with no backing disk", "/dev/loop0 loop\n", ""},
		{"empty", "", ""},
	} {
		if got := bottomDisk(c.tree); got != c.want {
			t.Fatalf("%s: bottomDisk = %q, want %q", c.name, got, c.want)
		}
	}
}

// bubbletea v2 delivers the space bar as "space", not " "; editInput must append
// a literal space (Wi-Fi/LUKS/user passphrases contain them). It was a no-op, so
// spaces silently vanished -- a post-install lockout for a password with a space.
func TestEditInputSpace(t *testing.T) {
	m := &model{}
	var s string
	m.editInput("h", &s)
	m.editInput("space", &s)
	m.editInput("i", &s)
	if s != "h i" {
		t.Fatalf("editInput dropped the space: got %q, want %q", s, "h i")
	}
	m.editInput("space", &s)     // "h i "
	m.editInput("backspace", &s) // removes the trailing space
	if s != "h i" {
		t.Fatalf("backspace after space: got %q, want %q", s, "h i")
	}
	before := s
	m.editInput("enter", &s) // enter commits a line; never a literal char
	if s != before {
		t.Fatalf("enter mutated the buffer: got %q, want %q", s, before)
	}
}

// alongside is GPT-only in the backend (it appends a partition and reads GPT
// partlabels): an MBR disk with plenty of free space must be blocked at the TUI,
// not die at backend stage 1. GPT + enough free clears the block.
func TestAlongsideRequiresGPT(t *testing.T) {
	mbr := model{picks: map[string]string{"disk": "alongside"}, gpt: false, diskG: 256, freeG: 200, espG: 1}
	if r := mbr.partBlockReason(); !strings.Contains(r, "GPT") {
		t.Fatalf("MBR alongside not blocked for GPT; got %q", r)
	}
	if mbr.partReady() {
		t.Fatal("partReady true on an MBR alongside layout")
	}
	gpt := mbr
	gpt.gpt = true
	if r := gpt.partBlockReason(); r != "" {
		t.Fatalf("GPT alongside with 200G free still blocked: %q", r)
	}
}

// alongside that must free leftover ryoku/ryokuboot partitions emits
// RYOKU_RECLAIM_LEFTOVERS=1 only after the typed-ERASE ack (wipeStage 2), and
// never the whole-disk RYOKU_WIPE_CONFIRMED token (that would drive the wrong
// backend path -- a zap-all instead of freeing just the leftovers).
func TestReclaimEnvOnlyAtStage2Alongside(t *testing.T) {
	base := func(stage int) model {
		return model{
			picks:    map[string]string{"disk": "alongside"},
			reclaim:  []part{{dev: "previous Ryoku", size: 30, reclaim: true}},
			reclaimG: 30, wipeStage: stage,
		}
	}
	for _, c := range []struct {
		stage int
		want  bool
	}{{0, false}, {1, false}, {2, true}} {
		env := base(c.stage).installEnv()
		if got := envHas(env, "RYOKU_RECLAIM_LEFTOVERS=1"); got != c.want {
			t.Fatalf("wipeStage %d: RYOKU_RECLAIM_LEFTOVERS present=%v, want %v", c.stage, got, c.want)
		}
		if envHas(env, "RYOKU_WIPE_CONFIRMED=1") {
			t.Fatalf("wipeStage %d: alongside must never emit RYOKU_WIPE_CONFIRMED", c.stage)
		}
	}
	// alongside with NO leftovers never emits the reclaim token, even at stage 2.
	m := model{picks: map[string]string{"disk": "alongside"}, wipeStage: 2}
	if envHas(m.installEnv(), "RYOKU_RECLAIM_LEFTOVERS=1") {
		t.Fatal("emitted RYOKU_RECLAIM_LEFTOVERS with no leftover partitions")
	}
	// whole at stage 2 still emits its own token and not the reclaim one.
	w := model{picks: map[string]string{"disk": "whole"}, existing: []part{{dev: "/dev/vda1"}}, wipeStage: 2}
	we := w.installEnv()
	if !envHas(we, "RYOKU_WIPE_CONFIRMED=1") || envHas(we, "RYOKU_RECLAIM_LEFTOVERS=1") {
		t.Fatalf("whole@stage2 tokens wrong: %v", we)
	}
}

// leftover Ryoku partitions will be freed, so their GiB counts toward the free
// figure the alongside gate uses (the backend reclaims BEFORE measuring). A tiny
// raw free region plus a big reclaimable partition must clear a layout the raw
// region alone could not.
func TestReclaimCountsTowardFree(t *testing.T) {
	m := model{picks: map[string]string{"disk": "alongside"}, gpt: true, diskG: 256, espG: 1, freeG: 4,
		reclaim: []part{{dev: "previous Ryoku", size: 40, reclaim: true}}, reclaimG: 40}
	if got := m.freeAlongside(); got != 44 {
		t.Fatalf("freeAlongside = %d, want 44 (4 free + 40 reclaimable)", got)
	}
	if !m.partReady() {
		t.Fatalf("alongside blocked despite 44G effective free: %q", m.partBlockReason())
	}
	if got := m.availRoot(); got != 42 { // reclaimed space folds into root, minus the 2 GiB boot
		t.Fatalf("availRoot = %d, want 42 (44 - 2G boot)", got)
	}
	// the same 4G raw region with NOTHING to reclaim stays blocked.
	m.reclaim, m.reclaimG = nil, 0
	if m.partReady() {
		t.Fatal("alongside ready with only 4G free and nothing to reclaim")
	}
}

// needsEraseAck gates the typed-ERASE confirmation: a populated whole-disk wipe,
// or an alongside install that must free leftover Ryoku partitions. Nothing else.
func TestNeedsEraseAck(t *testing.T) {
	reclaim := []part{{dev: "previous Ryoku", reclaim: true}}
	for _, c := range []struct {
		name string
		m    model
		want bool
	}{
		{"whole populated", model{picks: map[string]string{"disk": "whole"}, existing: []part{{dev: "x"}}}, true},
		{"whole blank", model{picks: map[string]string{"disk": "whole"}}, false},
		{"alongside with reclaim", model{picks: map[string]string{"disk": "alongside"}, reclaim: reclaim}, true},
		{"alongside no reclaim", model{picks: map[string]string{"disk": "alongside"}}, false},
	} {
		if got := c.m.needsEraseAck(); got != c.want {
			t.Fatalf("%s: needsEraseAck = %v, want %v", c.name, got, c.want)
		}
	}
}

// reviewReclaimModel: model parked on Review with alongside + leftover Ryoku
// partitions, the state where the reclaim ERASE-ack gate fires.
func reviewReclaimModel() model {
	flow := steps()
	m := model{
		flow:      flow,
		picks:     map[string]string{"disk": "alongside"},
		gpt:       true,
		reclaim:   []part{{dev: "previous Ryoku", size: 30, reclaim: true}},
		reclaimG:  30,
		yes:       true,
		netOnline: true,
	}
	for i, st := range flow {
		if st.key == "review" {
			m.idx = i
			break
		}
	}
	return m
}

// alongside with leftover Ryoku partitions must NOT install on the first Enter:
// it enters the typed-ERASE sub-stage exactly like the whole-disk wipe does, so
// the backend never frees a partition without an explicit ack.
func TestReviewReclaimGateEntersConfirmStage(t *testing.T) {
	m := reviewReclaimModel()
	nm, cmd := m.onKey("enter")
	if cmd != nil {
		t.Fatal("Enter started an alongside install before the reclaim ERASE ack")
	}
	if n := nm.(model); n.wipeStage != 1 {
		t.Fatalf("wipeStage = %d, want 1 (reclaim ack prompt active)", n.wipeStage)
	}
}

// Enter on the default No used to quit and silently discard the whole session;
// now it is a no-op. Only an explicit Yes proceeds; esc/q still leave.
func TestReviewEnterOnNoIsNoop(t *testing.T) {
	m := reviewWipeModel()
	m.yes = false
	nm, cmd := m.onKey("enter")
	if cmd != nil {
		t.Fatal("Enter on No returned a command (quit); it must be a no-op")
	}
	n := nm.(model)
	if n.state == "install" || n.wipeStage != 0 {
		t.Fatalf("Enter on No advanced the flow: state=%q wipeStage=%d", n.state, n.wipeStage)
	}
	if n.idx != m.idx {
		t.Fatalf("Enter on No changed step idx %d -> %d", m.idx, n.idx)
	}
}

// on Enter the chosen SSID must resolve from the picker's OWN items, never a
// fresh ssids() rescan indexed by the stale cursor (a rescan can reorder/shorten
// the list, so the old code connected to the wrong network).
func TestSSIDResolvesFromPickerItems(t *testing.T) {
	flow := steps()
	m := model{flow: flow, picks: map[string]string{}}
	for i, st := range flow {
		if st.key == "network" {
			m.idx = i
			break
		}
	}
	m.netOnline, m.netStage = false, 0
	m.pick = newPicker([]item{{key: "Alpha", label: "Alpha"}, {key: "Beta Net", label: "Beta Net"}}, true)
	m.pick.cursor = 1
	nm, _ := m.onKey("enter")
	n := nm.(model)
	if n.netSSID != "Beta Net" {
		t.Fatalf("netSSID = %q, want %q (from picker items[cursor])", n.netSSID, "Beta Net")
	}
	if n.netStage != 1 {
		t.Fatalf("netStage = %d, want 1 (passphrase entry)", n.netStage)
	}
}

// splitNMTerse splits an nmcli -t line only on UNescaped ':' and unescapes the
// values, so an SSID containing ':' or '\' survives. A naive strings.Split(":")
// mangled such SSIDs (wrong field count, truncated name).
func TestSplitNMTerse(t *testing.T) {
	for _, c := range []struct {
		name, line string
		want       []string
	}{
		{"plain", "HomeNet:72:WPA2", []string{"HomeNet", "72", "WPA2"}},
		{"escaped colon in ssid", `Cafe\: WiFi:60:WPA2`, []string{"Cafe: WiFi", "60", "WPA2"}},
		{"escaped backslash", `Net\\Work:55:WPA2`, []string{`Net\Work`, "55", "WPA2"}},
		{"open network, empty security", "Guest:40:", []string{"Guest", "40", ""}},
		{"trailing escaped colon in ssid", `Weird\::10:WPA2`, []string{"Weird:", "10", "WPA2"}},
	} {
		got := splitNMTerse(c.line)
		if len(got) != len(c.want) {
			t.Fatalf("%s: %q -> %d fields %v, want %d %v", c.name, c.line, len(got), got, len(c.want), c.want)
		}
		for i := range got {
			if got[i] != c.want[i] {
				t.Fatalf("%s: field %d = %q, want %q (from %q)", c.name, i, got[i], c.want[i], c.line)
			}
		}
	}
}

// a BitLocker partition on an alongside target gets a non-blocking review warning
// pointing at the hardware doc; a whole-disk wipe (erased anyway) and a
// non-BitLocker disk get none.
func TestReviewBitLockerWarning(t *testing.T) {
	al := model{picks: map[string]string{"disk": "alongside"}, gpt: true, bitlocker: true, netOnline: true}
	body := al.reviewBody(72)
	if !strings.Contains(body, "BitLocker") || !strings.Contains(body, "installation-hardware.md") {
		t.Fatalf("alongside+BitLocker review missing the recovery-key warning:\n%s", body)
	}
	if b := (model{picks: map[string]string{"disk": "alongside"}, gpt: true, netOnline: true}).reviewBody(72); strings.Contains(b, "BitLocker") {
		t.Fatal("BitLocker warning shown with no BitLocker partition")
	}
	if b := (model{picks: map[string]string{"disk": "whole"}, bitlocker: true, netOnline: true}).reviewBody(72); strings.Contains(b, "BitLocker") {
		t.Fatal("BitLocker warning shown for a whole-disk wipe (disk is erased anyway)")
	}
}

// unescapeLsblk decodes lsblk -P \xNN hex escapes so partition labels with
// spaces and other special bytes (dual-boot data partitions, reclaim matching)
// carry their real text rather than the literal escape.
func TestUnescapeLsblk(t *testing.T) {
	for _, c := range []struct{ in, want string }{
		{"Windows\\x20Data", "Windows Data"},
		{"plain", "plain"},
		{"", ""},
		{"tab\\x09end", "tab\tend"},
		{"trailing\\x", "trailing\\x"}, // malformed tail left as-is
		{"ryoku", "ryoku"},
	} {
		if got := unescapeLsblk(c.in); got != c.want {
			t.Fatalf("unescapeLsblk(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}
