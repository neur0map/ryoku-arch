import QtQuick
import Quickshell
import Quickshell.Io
pragma Singleton

Singleton {
    id: root

    property bool running: false
    property var values: []
    property int barsCount: 32
    property var _parseBuffer: new Array(barsCount)
    property var config: ({
        "general": {
            "bars": barsCount,
            "framerate": 20,
            "autosens": 1,
            "sensitivity": 100,
            "lower_cutoff_freq": 50,
            "higher_cutoff_freq": 10000
        },
        "output": {
            "method": "raw",
            "data_format": "ascii",
            "ascii_max_range": 100,
            "bit_format": "8bit",
            "channels": "mono",
            "mono_option": "average"
        },
        "smoothing": {
            "monstercat": 1,
            "noise_reduction": 70
        }
    })

    Process {
        id: process

        stdinEnabled: true
        running: root.running
        command: ["cava", "-p", "/dev/stdin"]
        onStarted: {
            for (const k in config) {
                if (typeof config[k] !== "object") {
                    write(k + "=" + config[k] + "\n");
                    continue;
                }
                write("[" + k + "]\n");
                const obj = config[k];
                for (const k2 in obj) {
                    write(k2 + "=" + obj[k2] + "\n");
                }
            }
            stdinEnabled = false; // Close stdin to let Cava start
            values = Array(barsCount).fill(0);
        }
        onExited: {
            values = Array(barsCount).fill(0);
            stdinEnabled = true; // Reset for next run
        }

        stdout: SplitParser {
            onRead: (data) => {
                const buffer = root._parseBuffer;
                let idx = 0;
                let num = 0;
                for (let i = 0, len = data.length - 1; i < len; i++) {
                    const c = data.charCodeAt(i);
                    if (c === 59) {
                        buffer[idx++] = num * 0.01;
                        num = 0;
                    } else if (c >= 48 && c <= 57) {
                        num = num * 10 + (c - 48);
                    }
                }
                if (num > 0 || idx < root.barsCount)
                    buffer[idx++] = num * 0.01;

                root.values = buffer.slice(0, idx);
            }
        }

    }

}