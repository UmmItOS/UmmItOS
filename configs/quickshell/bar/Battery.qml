import Quickshell.Services.UPower
import QtQuick
import QtQuick.Layouts
import ".."

RowLayout {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property real pct: battery ? battery.percentage : 1
    readonly property bool charging: battery && battery.state === UPowerDeviceState.Charging
    readonly property bool low: pct < 0.2 && !charging

    // Desktops report no laptop battery, so this hides itself with no config.
    visible: battery ? battery.isLaptopBattery : false
    spacing: Theme.spacing.small

    MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: root.charging ? "battery_charging_full" : root.pct > 0.8 ? "battery_full" : root.pct > 0.4 ? "battery_5_bar" : root.pct > 0.2 ? "battery_3_bar" : "battery_alert"
        color: root.low ? Theme.urgent : Theme.fg
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        text: Math.round(root.pct * 100) + " %"
        color: root.low ? Theme.urgent : Theme.fg
        font.family: Theme.font
        font.pixelSize: Theme.fontSize.normal
    }
}
