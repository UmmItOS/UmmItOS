pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth as Bluez
import ".."

// What the computer is connected through, quietly; the pointer reads out every interface.
RowLayout {
    id: root

    readonly property var paired: Bluez.Bluetooth.devices.values.filter(d => d.connected)
    readonly property string adapter: Bluez.Bluetooth.defaultAdapter?.adapterId ?? ""

    readonly property string details: {
        const lines = NetIfaces.list.map(i => [i.kind, i.device, i.name === i.device ? "" : i.name].filter(p => p !== "").join(" · "));
        for (const d of root.paired)
            lines.push(["Bluetooth", root.adapter, d.name].filter(p => p !== "").join(" · "));
        return lines.length > 0 ? lines.join("\n") : I18n.t("No network");
    }

    spacing: Theme.spacing.extraSmall
    opacity: Theme.bar.netInfo

    HoverHandler {
        id: hover
    }

    Tip {
        anchorItem: root
        text: root.details
        wanted: hover.hovered
    }

    MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: !NetIfaces.main ? "wifi_off" : NetIfaces.main.kind === "LAN" ? "lan" : "wifi"
        color: NetIfaces.main ? Theme.fg : Theme.urgent
        size: Theme.icon.small
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        Layout.maximumWidth: Theme.bar.netName
        textFormat: Text.PlainText
        text: NetIfaces.main ? (NetIfaces.main.kind === "LAN" ? I18n.t("LAN") : NetIfaces.main.name) : I18n.t("No network")
        color: NetIfaces.main ? Theme.fg : Theme.urgent
        elide: Text.ElideRight
        font.family: Theme.font
        font.pixelSize: Theme.fontSize.small
    }

    MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        visible: NetIfaces.vpn
        text: "vpn_lock"
        color: Theme.fg
        size: Theme.icon.small
    }

    MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        visible: root.paired.length > 0
        text: "bluetooth"
        color: Theme.fg
        size: Theme.icon.small
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        Layout.maximumWidth: Theme.bar.netName
        visible: root.paired.length > 0
        textFormat: Text.PlainText
        text: root.paired.map(d => d.name).join(", ")
        color: Theme.fg
        elide: Text.ElideRight
        font.family: Theme.font
        font.pixelSize: Theme.fontSize.small
    }
}
