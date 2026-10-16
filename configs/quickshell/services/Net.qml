pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import ".."

// One sampler however many bars, idle under the lock; the first sample is only a baseline.
Singleton {
    id: root

    readonly property string device: {
        const dev = Networking.devices.values.find(d => d.connected);
        return dev ? dev.name : "";
    }

    property real downRate: 0
    property real upRate: 0
    // The last chartSamples seconds, oldest first, for the bar's hover chart.
    property var downHist: []
    property var upHist: []
    property real lastRx: -1
    property real lastTx: -1

    // One decimal below ten keeps the string length steady.
    function human(bytes: real): string {
        if (bytes >= 1048576) {
            const m = bytes / 1048576;
            return (m < 10 ? m.toFixed(1) : Math.round(m)) + " M";
        }
        if (bytes >= 1024) {
            const k = bytes / 1024;
            return (k < 10 ? k.toFixed(1) : Math.round(k)) + " k";
        }
        return Math.round(bytes) + " B";
    }

    // Reset the baseline on a new interface.
    onDeviceChanged: {
        downHist = [];
        upHist = [];
        lastRx = -1;
        lastTx = -1;
        downRate = 0;
        upRate = 0;
    }

    Timer {
        onTriggered: stat.reload()

        running: root.device !== "" && !Lock.locked
        interval: 1000
        repeat: true
        triggeredOnStart: true
    }

    FileView {
        id: stat

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
                    root.downHist = root.downHist.slice(1 - Theme.bar.chartSamples).concat(root.downRate);
                    root.upHist = root.upHist.slice(1 - Theme.bar.chartSamples).concat(root.upRate);
                }
                root.lastRx = rx;
                root.lastTx = tx;
                return;
            }
        }

        path: "/proc/net/dev"
        printErrors: false
    }
}
