package main

import (
	"strings"
	"testing"
)

// the frozen probe line: 9 positional fields then a free-text reason. parse must
// keep the numbers exact, treat "-" as no label, and read shrinkable from field 9.
func TestParseResizeParts(t *testing.T) {
	out := strings.Join([]string{
		"sectorsize 512",
		"esp /dev/nvme0n1p1",
		"part /dev/nvme0n1p1 1 vfat ESP 1024 42 -1 no ESP: not carveable",
		"part /dev/nvme0n1p3 3 btrfs ryoku 951000 420000 490000 yes single-device btrfs",
		"part /dev/sda3 3 BitLocker Basic_data 512000 -1 -1 no BitLocker: decrypt in Windows first",
		"part /dev/sda4 4 ntfs - 200000 90000 100000 yes clean NTFS",
		"verdict ok",
	}, "\n")
	parts := parseResizeParts(out)
	if len(parts) != 4 {
		t.Fatalf("got %d part lines, want 4: %+v", len(parts), parts)
	}
	btr := parts[1]
	if btr.dev != "/dev/nvme0n1p3" || btr.index != 3 || btr.fs != "btrfs" || btr.label != "ryoku" {
		t.Fatalf("btrfs part header wrong: %+v", btr)
	}
	if btr.sizeMiB != 951000 || btr.usedMiB != 420000 || btr.minMiB != 490000 {
		t.Fatalf("btrfs sizes wrong: %+v", btr)
	}
	if !btr.shrinkable || btr.reason != "single-device btrfs" {
		t.Fatalf("btrfs shrinkable/reason wrong: %+v", btr)
	}
	// a refusal carries its full multi-word reason verbatim.
	bl := parts[2]
	if bl.shrinkable || bl.reason != "BitLocker: decrypt in Windows first" {
		t.Fatalf("bitlocker refusal wrong: %+v", bl)
	}
	// -1 used/min survive as -1; "-" label becomes empty.
	if bl.usedMiB != -1 || bl.minMiB != -1 {
		t.Fatalf("bitlocker -1 sentinels lost: %+v", bl)
	}
	if parts[3].label != "" {
		t.Fatalf(`"-" label should parse as empty, got %q`, parts[3].label)
	}
}

// malformed and non-part lines are skipped, never trusted: a garbled probe must
// fail closed to "nothing here", not fabricate a bad carve target.
func TestParseResizePartsSkipsJunk(t *testing.T) {
	out := strings.Join([]string{
		"region 2048 100000 400",
		"part /dev/sda1 1 ntfs Data notanumber 10 10 yes x", // non-numeric size
		"part /dev/sda2",                                    // too few fields
		"part /dev/sda3 3 ext4 root 100 10 5 yes ok",        // valid
		"garbage line",
	}, "\n")
	parts := parseResizeParts(out)
	if len(parts) != 1 || parts[0].dev != "/dev/sda3" {
		t.Fatalf("only the valid part line should survive, got %+v", parts)
	}
}

// probeResize runs the backend verb and parses its part lines end to end.
func TestProbeResizeViaStub(t *testing.T) {
	stubBackend(t, "sectorsize 512\npart /dev/sda3 3 ntfs Windows 512000 130000 210000 yes clean NTFS\nverdict ok")
	parts := probeResize("/dev/sda")
	if len(parts) != 1 || !parts[0].shrinkable || parts[0].dev != "/dev/sda3" {
		t.Fatalf("probeResize parse wrong: %+v", parts)
	}
}

// carve bounds: floor is Ryoku's minimum (boot + root floor); ceiling is the
// partition's headroom above its filesystem minimum; the default is half the
// headroom, capped at 64 GiB, never below the floor.
func TestCarveBounds(t *testing.T) {
	m := model{}
	floorMiB := int64(alongsideBootGiB+minRootGiB) * 1024
	if m.carveFloorMiB() != floorMiB {
		t.Fatalf("floor = %d, want %d", m.carveFloorMiB(), floorMiB)
	}
	// big partition: headroom huge, default caps at 64 GiB.
	big := resizePart{sizeMiB: 900 * 1024, minMiB: 200 * 1024, shrinkable: true}
	if got := m.carveCeilMiB(big); got != 700*1024 {
		t.Fatalf("ceil = %d, want %d", got, 700*1024)
	}
	if got := m.carveDefaultMiB(big); got != 64*1024 {
		t.Fatalf("default = %d, want 64 GiB (%d)", got, 64*1024)
	}
	// mid headroom: default = half the headroom (above the floor, below the 64 GiB cap).
	mid := resizePart{sizeMiB: 200 * 1024, minMiB: 100 * 1024, shrinkable: true} // headroom 100, half 50
	if got := m.carveDefaultMiB(mid); got != 50*1024 {
		t.Fatalf("default = %d, want half of 100 GiB headroom (50 GiB)", got)
	}
	// default is floored: a partition whose half-headroom would fall under the
	// Ryoku minimum still defaults to at least the floor.
	tight := resizePart{sizeMiB: 70 * 1024, minMiB: 40 * 1024, shrinkable: true} // headroom 30, half 15 < floor 22
	if got := m.carveDefaultMiB(tight); got != floorMiB {
		t.Fatalf("default = %d, want the floor %d", got, floorMiB)
	}
}

// carveablePart: only shrinkable partitions with headroom clearing the floor.
func TestCarveablePart(t *testing.T) {
	m := model{}
	yes := resizePart{sizeMiB: 100 * 1024, minMiB: 40 * 1024, shrinkable: true} // headroom 60 > floor 22
	no1 := resizePart{sizeMiB: 100 * 1024, minMiB: 40 * 1024, shrinkable: false}
	no2 := resizePart{sizeMiB: 30 * 1024, minMiB: 20 * 1024, shrinkable: true} // headroom 10 < floor 22
	if !m.carveablePart(yes) {
		t.Fatal("shrinkable with room must be carveable")
	}
	if m.carveablePart(no1) {
		t.Fatal("non-shrinkable must not be carveable")
	}
	if m.carveablePart(no2) {
		t.Fatal("too-full partition (headroom < floor) must not be carveable")
	}
}

// carveModel: an alongside disk driven by a resize probe. Windows NTFS is the
// carve target; the ESP is present but not carveable.
func carveModel(freeG int) model {
	m := model{
		picks: map[string]string{"disk": "alongside"}, gpt: true, diskG: 1024,
		espG: 1, swapG: 16, freeG: freeG, carvePart: -1,
		resizeParts: []resizePart{
			{dev: "/dev/sda1", index: 1, fs: "vfat", label: "ESP", sizeMiB: 1024, usedMiB: 42, minMiB: -1, shrinkable: false, reason: "ESP: not carveable"},
			{dev: "/dev/sda2", index: 2, fs: "ntfs", label: "", sizeMiB: 900 * 1024, usedMiB: 180 * 1024, minMiB: 200 * 1024, shrinkable: true, reason: "clean NTFS"},
		},
	}
	if len(m.reclaim) == 0 && m.freeG < minRootGiB+alongsideBootGiB {
		m.selectDefaultCarve()
	}
	m.clampSwapToLayout()
	return m
}

// a fully-allocated disk (no gap) auto-selects the largest carveable partition at
// its default take, so the carve path is live the instant the page opens.
func TestCarveDefaultSelection(t *testing.T) {
	m := carveModel(0)
	if !m.carving() {
		t.Fatal("a full disk with a shrinkable partition must default to carving")
	}
	if m.carvePart != 1 {
		t.Fatalf("carvePart = %d, want 1 (the NTFS partition)", m.carvePart)
	}
	if m.carveTakeMiB != 64*1024 {
		t.Fatalf("default take = %d, want 64 GiB", m.carveTakeMiB)
	}
}

// scrubbing clamps the take into [floor, headroom]: never below Ryoku's minimum,
// never past what the filesystem can give up.
func TestCarveScrubClamps(t *testing.T) {
	m := carveModel(0)
	floor, ceil := m.carveFloorMiB(), m.carveCeilMiB(m.resizeParts[1])
	// slam left well past the floor.
	for range 1000 {
		m.carveScrub(1, -carveBigStepMiB)
	}
	if m.carveTakeMiB != floor {
		t.Fatalf("take = %d after scrubbing down, want floor %d", m.carveTakeMiB, floor)
	}
	// slam right well past the ceiling.
	for range 100000 {
		m.carveScrub(1, carveBigStepMiB)
	}
	if m.carveTakeMiB != ceil {
		t.Fatalf("take = %d after scrubbing up, want ceiling %d", m.carveTakeMiB, ceil)
	}
}

// scrubbing a different carve row selects it and seeds its default take.
func TestCarveScrubSelects(t *testing.T) {
	m := carveModel(200) // roomy gap: nothing auto-selected
	if m.carving() {
		t.Fatal("a roomy gap should not auto-carve")
	}
	m.carveScrub(1, 0) // touch the NTFS row
	if !m.carving() || m.carvePart != 1 {
		t.Fatalf("scrubbing row 1 must select it: carving=%v part=%d", m.carving(), m.carvePart)
	}
	if m.carveTakeMiB != m.carveDefaultMiB(m.resizeParts[1]) {
		t.Fatalf("selecting must seed the default take, got %d", m.carveTakeMiB)
	}
}

// the carve contract: a carving install exports RYOKU_RESIZE_PART + TAKE_MIB and
// must NOT export the region sectors (the backend opens the gap, then computes
// them itself).
func TestCarveEnvVars(t *testing.T) {
	m := carveModel(0)
	m.carveTakeMiB = 120 * 1024
	env := m.installEnv()
	if !envHas(env, "RYOKU_RESIZE_PART=/dev/sda2") {
		t.Fatalf("missing RYOKU_RESIZE_PART: %v", env)
	}
	if !envHas(env, "RYOKU_RESIZE_TAKE_MIB=122880") {
		t.Fatalf("missing/!= RYOKU_RESIZE_TAKE_MIB=122880: %v", env)
	}
	if _, ok := envValue(env, "RYOKU_REGION_START"); ok {
		t.Fatalf("carve must not export region sectors: %v", env)
	}
}

// the region contract is unchanged: an alongside install using an existing gap
// exports the region sectors and NOT the carve vars.
func TestRegionEnvNoCarveVars(t *testing.T) {
	m := carveModel(200) // roomy gap, carvePart stays -1
	m.regionStart, m.regionEnd = 2048, 90000000
	env := m.installEnv()
	if !envHas(env, "RYOKU_REGION_START=2048") || !envHas(env, "RYOKU_REGION_END=90000000") {
		t.Fatalf("region install must export region sectors: %v", env)
	}
	if _, ok := envValue(env, "RYOKU_RESIZE_PART"); ok {
		t.Fatalf("a non-carve install must not export RYOKU_RESIZE_PART: %v", env)
	}
}

// diskSummary is the picker's one-line "what's on it": headline occupant, count
// of the rest, free headroom (or "full"). Matches the design's example strings.
func TestDiskSummary(t *testing.T) {
	cases := []struct {
		name string
		dl   diskLayout
		want string
	}{
		{"empty", diskLayout{}, "empty"},
		{"windows", diskLayout{windows: true, freeG: 190, parts: []part{{}, {}, {}, {}}}, "Windows + 3 more · 190 GiB free"},
		{"ryoku full", diskLayout{parts: []part{{dev: "ryoku", size: 900}}}, "ryoku · full"},
		{"generic", diskLayout{freeG: 10, parts: []part{{dev: "DATA", size: 500}}}, "DATA · 10 GiB free"},
	}
	for _, c := range cases {
		if got := diskSummary(c.dl); got != c.want {
			t.Fatalf("%s: diskSummary = %q, want %q", c.name, got, c.want)
		}
	}
}

// existingSegs is the content map: every probed partition (with its used GiB for
// shading) plus the trailing free region.
func TestExistingSegs(t *testing.T) {
	m := carveModel(50) // roomy gap, not carving
	segs := m.existingSegs()
	// ESP + NTFS + free = 3 segments.
	if len(segs) != 3 {
		t.Fatalf("got %d segs, want 3: %+v", len(segs), segs)
	}
	win := segs[1]
	if win.size != 900 || win.used != 180 {
		t.Fatalf("NTFS seg = size %d used %d, want 900/180", win.size, win.used)
	}
	free, ok := segByFS(segs, "") // the free gap carries no fs
	if !ok || free.status != "free" || free.size != 50 {
		t.Fatalf("free gap = %+v (ok=%v), want a 50 GiB free seg", free, ok)
	}
}

// the live preview: carving shrinks the chosen partition and grows a Ryoku root
// in the freed space — bigger take, bigger root, smaller Windows.
func TestMapSegsPreview(t *testing.T) {
	m := carveModel(0) // auto-carves NTFS at 64 GiB
	m.carveTakeMiB = 120 * 1024
	m.swapG = 16
	segs := m.mapSegs()
	root, ok := segByMount(segs, "/")
	if !ok {
		t.Fatalf("preview has no Ryoku root: %+v", segs)
	}
	// root = take - boot - swap = 120 - 2 - 16 = 102.
	if root.size != 120-alongsideBootGiB-16 {
		t.Fatalf("root = %d, want %d", root.size, 120-alongsideBootGiB-16)
	}
	// Windows shrinks by exactly the take: 900 - 120 = 780.
	win := segs[m.carvePart]
	if win.fs != "ntfs" || win.size != 900-120 {
		t.Fatalf("shrunk NTFS = %+v, want size %d", win, 900-120)
	}
	// growing the take grows the root and shrinks Windows further.
	m.carveTakeMiB = 200 * 1024
	segs2 := m.mapSegs()
	root2, _ := segByMount(segs2, "/")
	if !(root2.size > root.size) {
		t.Fatalf("more take must grow root: %d !> %d", root2.size, root.size)
	}
	if segs2[m.carvePart].size >= win.size {
		t.Fatalf("more take must shrink Windows: %d !< %d", segs2[m.carvePart].size, win.size)
	}
}

// idle (no carve chosen), the map bar is the disk exactly as it is now.
func TestMapSegsIdleIsExisting(t *testing.T) {
	m := carveModel(50)
	if m.carving() {
		t.Fatal("roomy gap should not be carving")
	}
	if len(m.mapSegs()) != len(m.existingSegs()) {
		t.Fatal("idle map must equal the existing layout")
	}
}

// the carve chooser rows: an existing-gap radio when the gap is big enough, one
// carve row per shrinkable partition, and non-shrinkable partitions kept OUT of
// the rows (they surface as dimmed reasons instead).
func TestLayoutRowsCarveUI(t *testing.T) {
	m := carveModel(200) // gap big enough -> region row present
	var region, carve int
	for _, r := range m.layoutRows() {
		switch r.kind {
		case "region":
			region++
		case "carve":
			carve++
		}
	}
	if region != 1 {
		t.Fatalf("want 1 region row with a roomy gap, got %d", region)
	}
	if carve != 1 {
		t.Fatalf("want 1 carve row (only the NTFS is shrinkable), got %d", carve)
	}
	// no gap -> no region row.
	if r := 0; func() int {
		for _, row := range carveModel(0).layoutRows() {
			if row.kind == "region" {
				r++
			}
		}
		return r
	}() != 0 {
		t.Fatal("a full disk must not offer the existing-gap row")
	}
}

// blocked-state honesty: a carving selection installs cleanly (""); a disk with
// no gap and nothing shrinkable says exactly that.
func TestCarveBlockReasonHonesty(t *testing.T) {
	if got := carveModel(0).partBlockReason(); got != "" {
		t.Fatalf("a valid carve must not block: %q", got)
	}
	// full disk, only an ESP (never carveable): explain, don't dead-end.
	m := model{
		picks: map[string]string{"disk": "alongside"}, gpt: true, diskG: 1024, freeG: 0, carvePart: -1,
		resizeParts: []resizePart{
			{dev: "/dev/sda1", fs: "vfat", label: "ESP", sizeMiB: 1024, minMiB: -1, shrinkable: false, reason: "ESP: not carveable"},
		},
	}
	got := m.partBlockReason()
	if got == "" || !strings.Contains(got, "no partition") {
		t.Fatalf("no-gap no-shrinkable disk must explain itself, got %q", got)
	}
}

// leftovers and a living carve target coexist: the carve UI stays on (a shrinkable
// partition drives it) while the leftovers render as their own dimmed freed
// segments -- never conflated with the kept/carved partitions.
func TestCarveCoexistsWithReclaim(t *testing.T) {
	m := model{
		picks: map[string]string{"disk": "alongside"}, gpt: true, diskG: 1024, freeG: 0, carvePart: -1,
		reclaim:     []part{{dev: "previous Ryoku", size: 8, status: "reclaim"}},
		reclaimG:    8,
		resizeParts: []resizePart{{dev: "/dev/sda3", fs: "ntfs", label: "", sizeMiB: 900 * 1024, minMiB: 200 * 1024, shrinkable: true}},
	}
	if !m.carveUI() {
		t.Fatal("a shrinkable partition must keep the carve UI on even with leftovers present")
	}
	// the leftover shows as a dimmed reclaimed segment, distinct from the carve target.
	var reclaimSegs int
	for _, s := range m.existingSegs() {
		if s.status == "reclaim" {
			reclaimSegs++
		}
	}
	if reclaimSegs != 1 {
		t.Fatalf("want 1 reclaimed segment, got %d", reclaimSegs)
	}
	// and a reclaim row is listed so the user sees it will be freed.
	var reclaimRows int
	for _, r := range m.layoutRows() {
		if r.kind == "reclaim" {
			reclaimRows++
		}
	}
	if reclaimRows != 1 {
		t.Fatalf("want 1 reclaim row, got %d", reclaimRows)
	}
}
