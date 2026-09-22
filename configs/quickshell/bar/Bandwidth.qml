pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import ".."

// Throughput, as sampled by the Net service. One bar per screen, one sampler.
RowLayout {
    id: root

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
        value: Net.downRate
    }

    Rate {
        Layout.alignment: Qt.AlignVCenter
        Layout.leftMargin: Theme.spacing.small
        glyph: "north"
        value: Net.upRate
    }

    // The bar's only other live numbers are the machine's own, so this is where
    // they hang: CPU, memory, storage, temperatures.
    TapHandler {
        onTapped: Dashboard.toggleTab(1)
    }
}
