import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property real pct: battery ? battery.percentage : 1
    readonly property int state: battery ? battery.state : UPowerDeviceState.Unknown

    readonly property bool charging: state === UPowerDeviceState.Charging || state === UPowerDeviceState.PendingCharge
    readonly property bool full: state === UPowerDeviceState.FullyCharged
    readonly property bool low: pct < 0.2 && !charging && !full

    // Green while it is filling or filled, amber on the way down, red when the
    // number actually matters. Colour carries the state; the icon carries the level.
    readonly property color tone: {
        if (low)
            return Theme.urgent;
        if (charging || full)
            return Theme.good;
        if (pct < 0.4)
            return Theme.warn;
        return Theme.fg;
    }

    readonly property string glyph: {
        if (full)
            return "battery_full";
        if (charging) {
            if (pct >= 0.9)
                return "battery_charging_90";
            if (pct >= 0.8)
                return "battery_charging_80";
            if (pct >= 0.6)
                return "battery_charging_60";
            if (pct >= 0.5)
                return "battery_charging_50";
            if (pct >= 0.3)
                return "battery_charging_30";
            return "battery_charging_20";
        }
        if (pct < 0.1)
            return "battery_alert";
        if (pct >= 0.95)
            return "battery_full";
        if (pct >= 0.8)
            return "battery_6_bar";
        if (pct >= 0.65)
            return "battery_5_bar";
        if (pct >= 0.5)
            return "battery_4_bar";
        if (pct >= 0.35)
            return "battery_3_bar";
        if (pct >= 0.2)
            return "battery_2_bar";
        return "battery_1_bar";
    }

    // Desktops report no laptop battery, so this hides itself with no config.
    visible: battery ? battery.isLaptopBattery : false
    spacing: Theme.spacing.small

    MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: root.glyph
        color: root.tone
        // Filled while charging so the state reads before the number does.
        fill: root.charging || root.full ? 1 : 0

        Behavior on color {
            ColorAnimation {
                duration: Theme.duration.expressiveDefaultEffects
            }
        }

        // A charging battery is the one state worth a pulse.
        SequentialAnimation on opacity {
            running: root.charging
            loops: Animation.Infinite
            alwaysRunToEnd: true

            NumberAnimation {
                to: 0.45
                duration: Theme.duration.large
                easing.type: Easing.InOutQuad
            }
            NumberAnimation {
                to: 1
                duration: Theme.duration.large
                easing.type: Easing.InOutQuad
            }
        }
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        text: Math.round(root.pct * 100) + " %"
        color: root.tone
        font.family: Theme.font
        font.pixelSize: Theme.fontSize.normal
        font.features: ({
                tnum: 1
            })

        Behavior on color {
            ColorAnimation {
                duration: Theme.duration.expressiveDefaultEffects
            }
        }
    }
}
