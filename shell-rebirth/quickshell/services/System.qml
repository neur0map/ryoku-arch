pragma Singleton
import QtQuick
import Quickshell.Io
import Quickshell
import qs.services

Singleton {
    id: stats

    property real cpu: 0
    property real ram: 0
    property real disk: 0
    property real temp: 0
    property string uptime: "0h 0m"

    property int brightness: 0
    property int lastBrightness: -1

    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: {
            cpuProc.running = true
            ramProc.running = true
            diskProc.running = true
            tempProc.running = true
            uptimeProc.running = true
        }
    }

    Timer {
        interval: 500
        running: true
        repeat: true
        onTriggered: {
            brightnessProc.running = true
        }
    }

    Process {
        id: cpuProc
        command: ["bash","-c","top -bn1 | grep 'Cpu(s)' | awk '{print 100-$8}'"]
        stdout: StdioCollector {
            onStreamFinished: stats.cpu = parseFloat(text) || 0
        }
    }

    Process {
        id: ramProc
        command: ["bash","-c","free | awk '/Mem:/ {print $3/$2 * 100.0}'"]
        stdout: StdioCollector {
            onStreamFinished: stats.ram = parseFloat(text) || 0
        }
    }

    Process {
        id: diskProc
        command: ["bash","-c","df -h / | awk 'NR==2 {print $5}' | sed 's/%//'"]
        stdout: StdioCollector {
            onStreamFinished: stats.disk = parseFloat(text) || 0
        }
    }

    Process {
        id: tempProc
        command: ["bash","-c","sensors | grep 'Package id 0:' | awk '{print $4}' | sed 's/+//;s/°C//' || echo '0'"]
        stdout: StdioCollector {
            onStreamFinished: stats.temp = parseFloat(text) || 0
        }
    }

    Process {
        id: uptimeProc
        command: ["bash","-c","cat /proc/uptime | awk '{print int($1)}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                let seconds = parseInt(text) || 0
                let hours = Math.floor(seconds / 3600)
                let minutes = Math.floor((seconds % 3600) / 60)
                stats.uptime = hours + "h " + minutes + "m"
            }
        }
    }

    Process {
        id: brightnessProc
        command: [
            "bash","-c",
            "brightnessctl -m | cut -d, -f4 | tr -d '%'"
        ]

        stdout: StdioCollector {
            onStreamFinished: {
                let v = parseInt(text) || 0
                stats.brightness = v
            }
        }
    }

    onBrightnessChanged: {
        if (lastBrightness !== -1 && brightness !== lastBrightness) {
            Osd.show("brightness", brightness)
        }
        lastBrightness = brightness
    }

    function setBrightness(v) {
        setBrightnessProc.command = ["brightnessctl","set", v + "%"]
        setBrightnessProc.running = true
        stats.brightness = v
        Osd.show("brightness", v)  // Show OSD when user changes brightness
    }

    Process { id: setBrightnessProc }
}