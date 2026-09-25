import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property real pct: battery ? battery.percentage : 1
    // Not `state`: every Item already has one, for its States.
    readonly property int charge: battery ? battery.state : UPowerDeviceState.Unknown

    // Charging from the plug, not the battery's report; not at a charge limit.
    readonly property bool charging: !full && charge !== UPowerDeviceState.PendingCharge && (!UPower.onBattery || charge === UPowerDeviceState.Charging)
    // Drivers report "fully charged" briefly on plug-in; check the level.
    readonly property bool full: charge === UPowerDeviceState.FullyCharged && Math.round(pct * 100) >= 99
    readonly property bool low: pct < 0.2 && !charging && !full

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
        if (Math.round(pct * 100) >= 100)
            return "battery_full";
        if (pct >= 0.85)
            return "battery_6_bar";
        if (pct >= 0.7)
            return "battery_5_bar";
        if (pct >= 0.55)
            return "battery_4_bar";
        if (pct >= 0.4)
            return "battery_3_bar";
        if (pct >= 0.25)
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

        SequentialAnimation on opacity {
            // Not behind the lock, where nobody sees the bar it redraws.
            running: root.charging && !Lock.locked
            loops: Animation.Infinite
            alwaysRunToEnd: true

            NumberAnimation {
                to: 0.35
                duration: Theme.duration.extraLarge
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1
                duration: Theme.duration.extraLarge
                easing.type: Easing.InOutSine
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
