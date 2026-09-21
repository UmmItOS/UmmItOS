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

    // One decimal below ten, none above, so the string length barely moves and
    // the two readouts stay the same visual weight.
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

    // A threshold rather than zero, so the arrows do not flicker on idle chatter.
    readonly property real busyAt: 2048

    spacing: 0

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

    // Each arrow sits with its own number and the pair is spaced apart from the
    // other, so it reads as two readouts rather than four loose items.
    component Rate: RowLayout {
        required property string glyph
        required property real value

        // Nothing here may fill: a child that wants to grow makes this whole
        // row growable, which propagates up and eats the bar's centring
        // spacers. The number carries a fixed width instead.
        spacing: Theme.spacing.extraSmall

        MaterialIcon {
            Layout.alignment: Qt.AlignVCenter
            text: parent.glyph
            color: parent.value > root.busyAt ? Theme.accentText : Theme.dim
            size: Theme.icon.small

            Behavior on color {
                ColorAnimation {
                    duration: Theme.duration.expressiveDefaultEffects
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignVCenter
            Layout.preferredWidth: 46
            horizontalAlignment: Text.AlignLeft
            text: root.human(parent.value)
            color: Theme.fg
            font.family: Theme.font
            font.pixelSize: Theme.fontSize.smaller
            font.features: ({
                    tnum: 1
                })
        }
    }

    Rate {
        Layout.alignment: Qt.AlignVCenter
        glyph: "south"
        value: root.downRate
    }

    Rate {
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: Theme.spacing.small
        glyph: "north"
        value: root.upRate
    }
}
