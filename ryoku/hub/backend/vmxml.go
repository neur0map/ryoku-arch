package main

// vmxml.go: render a libvirt domain XML from a VM config. The defaults are tuned
// for a Looking-Glass passthrough guest: q35 + OVMF, host-passthrough CPU, hyperv
// enlightenments with a hidden KVM and spoofed vendor_id (NVIDIA code-43 insurance),
// swtpm TPM 2.0 + Secure Boot for Windows 11, virtio disk/net, the dGPU (and its
// sibling functions) as managed='no' hostdevs, and a kvmfr IVSHMEM device for
// Looking Glass with the memballoon disabled. A spice/qxl head stays for the first
// boot and install, before the guest driver and the IDD virtual display exist.

import (
	"bytes"
	"fmt"
	"strings"
	"text/template"
)

// kvmfrStaticMB is the Looking Glass shared-memory size (MiB), used for both the
// kvmfr module's static_size_mb and the VM's ivshmem device. 128 MiB covers SDR
// panels up to 2160p and most ultrawides; raising it only blocks that much RAM.
const kvmfrStaticMB = 128

type pciAddr struct {
	Domain, Bus, Slot, Func string // hex, e.g. 0x0000 0x01 0x00 0x0
}

type domainData struct {
	Name       string
	MemMB      int
	Cores      int
	IsWindows  bool
	IsoPath    string
	VirtioIso  string
	DiskPath   string
	Hostdevs   []pciAddr
	KvmfrBytes int64
}

// RenderDomain builds the libvirt domain XML. functions are the PCI slots to pass
// (the dGPU plus its sibling functions, e.g. its HDMI audio); kvmfrMB sizes the
// Looking Glass shared-memory device.
func RenderDomain(vm VM, functions []string, kvmfrMB int) (string, error) {
	if len(functions) == 0 {
		return "", fmt.Errorf("no passthrough PCI functions")
	}
	var addrs []pciAddr
	for _, f := range functions {
		a, err := parsePCIAddr(f)
		if err != nil {
			return "", err
		}
		addrs = append(addrs, a)
	}
	if kvmfrMB < kvmfrStaticMB {
		kvmfrMB = kvmfrStaticMB
	}
	d := domainData{
		Name:       vm.Name,
		MemMB:      vm.RamMB,
		Cores:      vm.Cores,
		IsWindows:  vm.Guest == "windows11",
		IsoPath:    vm.IsoPath,
		VirtioIso:  vm.VirtioIso,
		DiskPath:   vm.DiskPath,
		Hostdevs:   addrs,
		KvmfrBytes: int64(kvmfrMB) * 1024 * 1024,
	}
	var buf bytes.Buffer
	if err := domainTmpl.Execute(&buf, d); err != nil {
		return "", err
	}
	return buf.String(), nil
}

// KvmfrSizeMB is the Looking Glass shared-memory size for a resolution, per the
// project formula next_pow2(w*h*4*2 / 1MiB + 10), floored at the recommended
// 128 MiB so SDR panels up to 2160p and most ultrawides need no tuning.
func KvmfrSizeMB(w, h int) int {
	needMB := float64(w*h*4*2)/1024/1024 + 10
	mb := 1
	for float64(mb) < needMB {
		mb <<= 1
	}
	if mb < kvmfrStaticMB {
		mb = kvmfrStaticMB
	}
	return mb
}

// parsePCIAddr splits 0000:01:00.0 into hex domain/bus/slot/function fields.
func parsePCIAddr(slot string) (pciAddr, error) {
	parts := strings.FieldsFunc(slot, func(r rune) bool { return r == ':' || r == '.' })
	if len(parts) != 4 {
		return pciAddr{}, fmt.Errorf("bad pci slot %q", slot)
	}
	return pciAddr{
		Domain: "0x" + parts[0],
		Bus:    "0x" + parts[1],
		Slot:   "0x" + parts[2],
		Func:   "0x" + parts[3],
	}, nil
}

var domainTmpl = template.Must(template.New("domain").Parse(`<domain type='kvm' xmlns:qemu='http://libvirt.org/schemas/domain/qemu/1.0'>
  <name>{{.Name}}</name>
  <memory unit='MiB'>{{.MemMB}}</memory>
  <currentMemory unit='MiB'>{{.MemMB}}</currentMemory>
  <vcpu placement='static'>{{.Cores}}</vcpu>
  <os firmware='efi'>
    <type arch='x86_64' machine='q35'>hvm</type>
{{- if .IsWindows}}
    <firmware>
      <feature enabled='yes' name='enrolled-keys'/>
      <feature enabled='yes' name='secure-boot'/>
    </firmware>
    <loader secure='yes'/>
{{- else}}
    <loader secure='no'/>
{{- end}}
    <boot dev='cdrom'/>
    <boot dev='hd'/>
  </os>
  <features>
    <acpi/>
    <apic/>
{{- if .IsWindows}}
    <smm state='on'/>
{{- end}}
    <hyperv mode='custom'>
      <relaxed state='on'/>
      <vapic state='on'/>
      <spinlocks state='on' retries='8191'/>
      <vendor_id state='on' value='ryoku12345'/>
    </hyperv>
    <kvm>
      <hidden state='on'/>
    </kvm>
    <vmport state='off'/>
  </features>
  <cpu mode='host-passthrough' check='none' migratable='on'>
    <topology sockets='1' dies='1' cores='{{.Cores}}' threads='1'/>
    <feature policy='disable' name='hypervisor'/>
  </cpu>
  <clock offset='localtime'>
    <timer name='rtc' tickpolicy='catchup'/>
    <timer name='pit' tickpolicy='delay'/>
    <timer name='hpet' present='no'/>
    <timer name='hypervclock' present='yes'/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <devices>
    <emulator>/usr/bin/qemu-system-x86_64</emulator>
    <disk type='file' device='disk'>
      <driver name='qemu' type='qcow2' discard='unmap'/>
      <source file='{{.DiskPath}}'/>
      <target dev='vda' bus='virtio'/>
    </disk>
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='{{.IsoPath}}'/>
      <target dev='sda' bus='sata'/>
      <readonly/>
    </disk>
{{- if .VirtioIso}}
    <disk type='file' device='cdrom'>
      <driver name='qemu' type='raw'/>
      <source file='{{.VirtioIso}}'/>
      <target dev='sdb' bus='sata'/>
      <readonly/>
    </disk>
{{- end}}
    <controller type='usb' model='qemu-xhci' ports='15'/>
    <interface type='network'>
      <source network='default'/>
      <model type='virtio'/>
    </interface>
{{- if .IsWindows}}
    <tpm model='tpm-crb'>
      <backend type='emulator' version='2.0'/>
    </tpm>
{{- end}}
{{- range .Hostdevs}}
    <hostdev mode='subsystem' type='pci' managed='no'>
      <source>
        <address domain='{{.Domain}}' bus='{{.Bus}}' slot='{{.Slot}}' function='{{.Func}}'/>
      </source>
    </hostdev>
{{- end}}
    <graphics type='spice' autoport='yes'>
      <listen type='address'/>
    </graphics>
    <video>
      <model type='qxl'/>
    </video>
    <input type='keyboard' bus='virtio'/>
    <input type='mouse' bus='virtio'/>
    <memballoon model='none'/>
  </devices>
  <qemu:commandline>
    <qemu:arg value='-device'/>
    <qemu:arg value='{"driver":"ivshmem-plain","id":"shmem0","memdev":"looking-glass"}'/>
    <qemu:arg value='-object'/>
    <qemu:arg value='{"qom-type":"memory-backend-file","id":"looking-glass","mem-path":"/dev/kvmfr0","size":{{.KvmfrBytes}},"share":true}'/>
  </qemu:commandline>
</domain>
`))
