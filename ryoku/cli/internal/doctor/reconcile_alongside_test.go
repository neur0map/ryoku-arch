package doctor

import "testing"

// isAlongsideSystem is true only when BOTH the shared ESP is mounted at /efi (an
// fstab entry) and our stage-1 hop is present. a whole-disk box (no /efi), a
// commented /efi line, or an /efi mount without the hop must all read false.
func TestIsAlongsideSystem(t *testing.T) {
	const alongsideFstab = "# /etc/fstab\n" +
		"UUID=aaaa /              btrfs rw,subvol=@        0 1\n" +
		"UUID=bbbb /boot          vfat  defaults          0 2\n" +
		"UUID=cccc /efi           vfat  defaults,nofail   0 2\n"
	const wholeFstab = "UUID=aaaa /     btrfs rw,subvol=@ 0 1\n" +
		"UUID=bbbb /boot vfat  defaults    0 2\n"
	const commentedEfi = "UUID=aaaa / btrfs rw,subvol=@ 0 1\n# UUID=cccc /efi vfat defaults 0 2\n"

	cases := []struct {
		name  string
		fstab string
		hop   bool
		want  bool
	}{
		{"alongside: /efi mount + hop", alongsideFstab, true, true},
		{"/efi mount but hop missing", alongsideFstab, false, false},
		{"whole-disk: no /efi mount", wholeFstab, true, false},
		{"commented /efi line does not count", commentedEfi, true, false},
		{"empty fstab", "", true, false},
	}
	for _, c := range cases {
		if got := isAlongsideSystem(c.fstab, c.hop); got != c.want {
			t.Errorf("%s: isAlongsideSystem = %v, want %v", c.name, got, c.want)
		}
	}
}

// fstabHasMount matches the mount point exactly in field 2, so /efi does not
// match /efi2 or a device field that merely contains "/efi".
func TestFstabHasMount(t *testing.T) {
	const fstab = "UUID=cccc /efi vfat defaults 0 2\nUUID=dddd /efi2 vfat defaults 0 2\n"
	if !fstabHasMount(fstab, "/efi") {
		t.Fatalf("fstabHasMount did not find the exact /efi mount")
	}
	if fstabHasMount(fstab, "/boot") {
		t.Fatalf("fstabHasMount matched a mount that is not present")
	}
	if fstabHasMount("/dev/efi /mnt ext4 defaults 0 0", "/efi") {
		t.Fatalf("fstabHasMount matched /efi in the device field, not the mount point")
	}
}

// hasAlongsideBootEntry matches the LOADER PATH (\EFI\ryoku\BOOTX64.EFI), not the
// "Ryoku" label, so a whole-disk Ryoku entry (\EFI\limine\limine_x64.efi) does
// NOT satisfy it. only active (starred) entries count; case is ignored because
// firmware may upcase the path. Fixtures mirror `efibootmgr -v`.
func TestHasAlongsideBootEntry(t *testing.T) {
	const header = "BootCurrent: 0004\nTimeout: 3\nBootOrder: 0004,0002\n"
	cases := []struct {
		name       string
		efibootmgr string
		want       bool
	}{
		{
			"active alongside entry",
			header + `Boot0004* Ryoku	HD(1,GPT,abcd,0x800,0x40000)/File(\EFI\ryoku\BOOTX64.EFI)`,
			true,
		},
		{
			"upcased loader path still matches",
			header + `Boot0004* Ryoku	HD(1,GPT,abcd,0x800,0x40000)/FILE(\EFI\RYOKU\BOOTX64.EFI)`,
			true,
		},
		{
			"whole-disk Ryoku (limine_x64) does not count",
			header + `Boot0004* Ryoku	HD(1,GPT,abcd,0x800,0x40000)/File(\EFI\limine\limine_x64.efi)`,
			false,
		},
		{
			"inactive alongside entry (no star) does not count",
			header + `Boot0004  Ryoku	HD(1,GPT,abcd,0x800,0x40000)/File(\EFI\ryoku\BOOTX64.EFI)`,
			false,
		},
		{"empty efibootmgr output", "", false},
	}
	for _, c := range cases {
		if got := hasAlongsideBootEntry(c.efibootmgr); got != c.want {
			t.Errorf("%s: hasAlongsideBootEntry = %v, want %v", c.name, got, c.want)
		}
	}
}
