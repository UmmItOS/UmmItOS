pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import ".."

// Throughput, as sampled by the Net service. One bar per screen, one sampler.
RowLayout {
    id: root

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

    // A threshold rather than zero, so the arrows do not flicker on idle chatter.
    readonly property real busyAt: 2048

    spacing: 0

    component Rate: RowLayout {
        required property string glyph
        required property real value

        // Nothing here may fill: it would eat the bar's centring.
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
            Layout.preferredWidth: Theme.control.readout
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

    TapHandler {
        onTapped: Dashboard.toggleTab(1)
    }
}
