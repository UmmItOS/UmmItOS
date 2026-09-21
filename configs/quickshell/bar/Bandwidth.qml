pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Networking
import QtQuick
import QtQuick.Layouts
import ".."

// Throughput read from /proc/net/dev, the same source waybar used. The rate is
// a difference between two samples, so the first sample only establishes a
// baseline and shows nothing.
RowLayout {
    id: root

    readonly property string device: {
        const dev = Networking.devices.values.find(d => d.connected);
        return dev ? dev.name : "";
    }

    property real downRate: 0
    property real upRate: 0
    property real lastRx: -1
    property real lastTx: -1

    function human(bytes: real): string {
        if (bytes >= 1048576)
            return (bytes / 1048576).toFixed(1) + "M";
        if (bytes >= 1024)
            return (bytes / 1024).toFixed(0) + "k";
        return Math.round(bytes) + "B";
    }

    spacing: Theme.spacing.small

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

    MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: "south"
        color: root.downRate > 0 ? Theme.accentText : Theme.dim
        size: Theme.icon.small
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: 46
        text: root.human(root.downRate)
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize.small
        font.features: ({
                tnum: 1
            })
    }

    MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: "north"
        color: root.upRate > 0 ? Theme.accentText : Theme.dim
        size: Theme.icon.small
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredWidth: 46
        text: root.human(root.upRate)
        color: Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize.small
        font.features: ({
                tnum: 1
            })
    }
}
