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
	if got := (model{diskG: 40, espG: 1}).swapCeil(); got != 31 {
		t.Fatalf("swapCeil small disk = %d, want 31 (39 - 8)", got)
	}
	if got := (model{diskG: 8, espG: 1}).swapCeil(); got != 0 {
		t.Fatalf("swapCeil tiny disk = %d, want 0 (never negative)", got)
	}
}

// growing ESP eats from the same pool, so an out-of-range swap gets clamped back.
func TestESPBumpClampsSwap(t *testing.T) {
	m := model{diskG: 40, espG: 1, swapG: 30}
	m.setRow("esp", 4) // availRoot 36 -> swapCeil 28
	if m.swapG != 28 {
		t.Fatalf("swap after esp bump = %d, want 28", m.swapG)
	}
}

// alongsideModel: build a dual-boot layout. 256 GiB disk, given free region,
// optionally already holding an ESP to reuse.
func alongsideModel(freeG, swapG int, withESP bool) model {
	m := model{picks: map[string]string{"disk": "alongside"}, diskG: 256, freeG: freeG, espG: 1, swapG: swapG}
	if withESP {
		m.kept = []part{{dev: "EFI System", size: 1, fs: "fat32", mount: "/boot", flags: "esp", status: "keep"}}
	} else {
		m.kept = []part{{dev: "Linux", size: 50, fs: "ext4", mount: "-", flags: "-", status: "keep"}}
	}
	return m
}

// alongside drops root into the detected free region and reuses the ESP, so
// root = free space minus the swapfile, never the whole disk.
func TestAlongsideRootUsesFreeSpace(t *testing.T) {
	m := alongsideModel(100, 16, true)
	if got := m.availRoot(); got != 100 {
		t.Fatalf("availRoot = %d, want 100 (the free region)", got)
	}
	root, ok := segByMount(m.layoutSegs(), "/")
	if !ok || root.size != 84 {
		t.Fatalf("root usable = %d (ok=%v), want 84 (100 - 16 swap)", root.size, ok)
	}
	for _, s := range m.layoutSegs() {
		if s.status == "new" && s.flags == "esp" {
			t.Fatal("alongside added a new ESP instead of reusing the existing one")
		}
	}
}

// alongside is only allowed with a reused ESP + enough contiguous free space
// (backend floor), so the TUI never hands the backend a layout it'd reject.
func TestAlongsidePartReady(t *testing.T) {
	if !alongsideModel(20, 0, true).partReady() {
		t.Fatal("alongside with an ESP and 20GiB free should be ready")
	}
	if alongsideModel(20, 0, false).partReady() {
		t.Fatal("alongside without an existing ESP must not be ready")
	}
	if alongsideModel(10, 0, true).partReady() {
		t.Fatalf("alongside with only 10GiB free (< %d) must not be ready", alongsideMinRootGiB)
	}
}

// alongside keeps the system base swap-free (matching backend), so its swapCeil
// leaves alongsideMinRootGiB instead of the 8 GiB a whole-disk leaves.
func TestAlongsideSwapCeil(t *testing.T) {
	if got := alongsideModel(40, 0, true).swapCeil(); got != 40-alongsideMinRootGiB {
		t.Fatalf("alongside swapCeil = %d, want %d", got, 40-alongsideMinRootGiB)
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
	m := alongsideModel(100, 16, true)
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

// A blocked partition step must say WHY, so Tab never dies silently. The common
// trap: accepting the default "alongside" on a disk with no ESP to reuse.
func TestPartBlockReasonExplainsBlockedTab(t *testing.T) {
	m := model{picks: map[string]string{"disk": "alongside"}, diskG: 256, freeG: 200}
	if r := m.partBlockReason(); r == "" {
		t.Fatal("partBlockReason empty for alongside with no reusable ESP; Tab would die silently")
	}
	m = model{picks: map[string]string{"disk": "whole"}, diskG: 256}
	if r := m.partBlockReason(); r != "" {
		t.Fatalf("partBlockReason %q for a valid whole-disk layout; want none", r)
	}
	if !m.partReady() {
		t.Fatal("partReady false while partBlockReason is empty; they must agree")
	}
}

// disk-strategy picker pre-selects items[0], so a quick Enter commits the first
// item. listing alongside first turns a fast Enter into the safe option
// (alongside is gated by free-space / ESP checks elsewhere); whole first turned
// a fast Enter into a disk wipe.
func TestDiskStrategyFirstItemIsAlongside(t *testing.T) {
	items := diskStrategies()
	if len(items) == 0 {
		t.Fatal("diskStrategies returned no items")
	}
	if items[0].key != "alongside" {
		t.Fatalf("first strategy item is %q, want \"alongside\" (safer default)", items[0].key)
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
		flow:     flow,
		picks:    map[string]string{"disk": "whole"},
		existing: []part{{dev: "/dev/vda1"}, {dev: "/dev/vda2"}},
		yes:      true,
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
