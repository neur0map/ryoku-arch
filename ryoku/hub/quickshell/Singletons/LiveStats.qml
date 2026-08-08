pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// LIVE system telemetry for the Profile plate -- the fast twin of SysInfo. A
// read-only glance (CPU, RAM and GPU load, two temperatures, VRAM, network
// rates and load average) computed in a single shot: two reads of /proc/stat and
// /proc/net/dev 0.3s apart give the CPU percentage and the byte rates, the rest
// are instantaneous. Re-polled every 1.5s while the plate is on screen, far
// faster than SysInfo's 30s dossier cadence, and gated to `active` so nothing
// beats when the page is gone. Writes nothing; each field falls to zero when its
// source is absent (no sensors, no nvidia-smi), so the plate degrades quietly.
Singleton {
    id: root

    // ProfilePage flips this on construction and off on destruction; the poll
    // loop only runs while the plate is the visible page.
    property bool active: false

    property int cpu: 0          // %
    property int ram: 0          // %
    property int cpuTemp: 0      // degrees C
    property real load: 0        // 1-minute load average
    property int netDown: 0      // bytes/s, summed over every non-loopback link
    property int netUp: 0        // bytes/s
    property int gpuUtil: 0      // %
    property int gpuTemp: 0      // degrees C
    property int vramUsed: 0     // MB
    property int vramTotal: 1    // MB
    property bool gpuOk: false   // false until a GPU line parses
    readonly property real vramPct: vramTotal > 0 ? 100 * vramUsed / vramTotal : 0

    // Increments on every successful poll. The sparklines watch it so they all
    // sample the same instant in lockstep, one trace step per poll.
    property int tick: 0

    Process {
        id: poller
        command: ["bash", "-c", `
s1=$(awk '/^cpu /{i=$5+$6;t=0;for(j=2;j<=NF;j++)t+=$j;print t,i}' /proc/stat)
n1=$(awk 'NR>2{gsub(/:/,"",$1);if($1!="lo"){rx+=$2;tx+=$10}}END{print rx+0,tx+0}' /proc/net/dev)
sleep 0.3
s2=$(awk '/^cpu /{i=$5+$6;t=0;for(j=2;j<=NF;j++)t+=$j;print t,i}' /proc/stat)
n2=$(awk 'NR>2{gsub(/:/,"",$1);if($1!="lo"){rx+=$2;tx+=$10}}END{print rx+0,tx+0}' /proc/net/dev)
cpu=$(awk -v a="$s1" -v b="$s2" 'BEGIN{split(a,x);split(b,y);dt=y[1]-x[1];di=y[2]-x[2];print (dt>0)?int(100*(dt-di)/dt+0.5):0}')
dn=$(awk -v a="$n1" -v b="$n2" 'BEGIN{split(a,x);split(b,y);d=(y[1]-x[1])/0.3;print (d>0)?int(d):0}')
up=$(awk -v a="$n1" -v b="$n2" 'BEGIN{split(a,x);split(b,y);d=(y[2]-x[2])/0.3;print (d>0)?int(d):0}')
ram=$(awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{print int(100*(t-a)/t+0.5)}' /proc/meminfo)
ld=$(awk '{print $1}' /proc/loadavg)
ct=$(sensors 2>/dev/null | awk '/Tctl/{v=$2;gsub(/[^0-9.]/,"",v);print int(v);exit}')
[ -z "$ct" ] && ct=$(awk '{print int($1/1000)}' /sys/class/thermal/thermal_zone0/temp 2>/dev/null)
g=$(nvidia-smi --query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total --format=csv,noheader,nounits 2>/dev/null | head -1 | tr ',' ' ')
echo "$cpu $ram $ct $ld $dn $up $g"
`]
        stdout: SplitParser {
            onRead: function (line) {
                const p = line.trim().split(/\s+/);
                if (p.length < 6)
                    return;
                root.cpu = parseInt(p[0]) || 0;
                root.ram = parseInt(p[1]) || 0;
                root.cpuTemp = parseInt(p[2]) || 0;
                root.load = parseFloat(p[3]) || 0;
                root.netDown = parseInt(p[4]) || 0;
                root.netUp = parseInt(p[5]) || 0;
                if (p.length >= 10) {
                    root.gpuUtil = parseInt(p[6]) || 0;
                    root.gpuTemp = parseInt(p[7]) || 0;
                    root.vramUsed = parseInt(p[8]) || 0;
                    root.vramTotal = parseInt(p[9]) || 1;
                    root.gpuOk = true;
                }
                root.tick++;
            }
        }
    }

    Timer {
        interval: 1500
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: poller.running = true
    }
}
