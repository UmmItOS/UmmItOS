pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick

// Throughput read from /proc/net/dev. A singleton because there is a bar per
// screen, and each used to read and parse the file every second on its own.
// The rate is a difference between two samples, so the first sample only
// establishes a baseline and shows nothing.
Singleton {
    id: root

    readonly property string device: {
        const dev = Networking.devices.values.find(d => d.connected);
        return dev ? dev.name : "";
    }

    property real downRate: 0
    property real upRate: 0
    property real lastRx: -1
    property real lastTx: -1

    Timer {
        running: root.device !== ""
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: stat.reload()
    }

    FileView {
        id: stat
        path: "/proc/net/dev"
        printErrors: false

        onLoaded: {
            for (const line of text().split("\n")) {
                const parts = line.trim().split(/\s+/);
                if (parts[0] !== root.device + ":")
                    continue;

                const rx = Number(parts[1]);
                const tx = Number(parts[9]);

                if (root.lastRx >= 0) {
                    root.downRate = Math.max(0, rx - root.lastRx);
                    root.upRate = Math.max(0, tx - root.lastTx);
                }
                root.lastRx = rx;
                root.lastTx = tx;
                return;
            }
        }
    }

    // Reset the baseline when the interface changes, or the first reading is a
    // meaningless jump between two different counters.
    onDeviceChanged: {
        lastRx = -1;
        lastTx = -1;
        downRate = 0;
        upRate = 0;
    }
}
