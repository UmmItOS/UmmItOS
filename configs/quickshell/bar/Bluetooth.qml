pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth as Bluez
import ".."

// Sits beside Wi-Fi and behaves the same way: a glyph in the bar and a flyout
// under it, with discovery running only while someone is looking.
//
// The module is imported under a namespace because this file is called
// Bluetooth too, and the local component would otherwise shadow the singleton.
RowLayout {
    id: root

    readonly property var adapter: Bluez.Bluetooth.defaultAdapter
    readonly property bool on: root.adapter?.enabled ?? false
    readonly property bool searching: root.on && (root.adapter?.discovering ?? false)
    readonly property var connectedDevice: [...Bluez.Bluetooth.devices.values].find(d => d.connected) ?? null

    // Connected first, then the ones already paired, then by name.
    readonly property var devices: [...Bluez.Bluetooth.devices.values].sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (a.name ?? "").localeCompare(b.name ?? ""))

    property bool popupOpen: false

    // BlueZ reports a freedesktop icon class; the bar speaks Material.
    function glyph(device: var): string {
        switch (device.icon ?? "") {
        case "audio-headset":
        case "audio-headphones":
            return "headphones";
        case "audio-card":
            return "speaker";
        case "input-mouse":
            return "mouse";
        case "input-keyboard":
            return "keyboard";
        case "input-gaming":
            return "sports_esports";
        case "phone":
            return "smartphone";
        case "computer":
            return "computer";
        default:
            return "bluetooth";
        }
    }

    spacing: Theme.spacing.small

    MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: {
            if (!root.adapter || !root.on)
                return "bluetooth_disabled";
            return root.connectedDevice ? "bluetooth_connected" : "bluetooth";
        }
        color: root.connectedDevice ? Theme.fg : Theme.dim
    }

    TapHandler {
        onTapped: root.popupOpen = !root.popupOpen
    }

    HoverHandler {
        id: barHover
    }

    Flyout {
        anchorItem: root
        anchorHovered: barHover.hovered
        visible: root.popupOpen
        title: "Bluetooth"
        busy: root.searching && root.devices.length > 0
        checked: root.on
        onToggled: root.adapter.enabled = !root.adapter.enabled
        onCloseRequested: root.popupOpen = false

        // Scanning drains the radio; run it only while the list is up.
        Binding {
            target: root.adapter
            property: "discovering"
            value: root.popupOpen && root.on
            when: root.adapter !== null
        }

        // Every empty case says which one it is.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: !root.adapter || !root.on || root.devices.length === 0

            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: Theme.spacing.medium

                MaterialIcon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: !root.searching
                    text: root.on ? "bluetooth_searching" : "bluetooth_disabled"
                    color: Theme.dim
                    size: Theme.icon.large
                }

                Spinner {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: root.searching
                    size: Theme.icon.large
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: {
                        if (!root.adapter)
                            return "No Bluetooth adapter";
                        if (!root.on)
                            return "Bluetooth is off";
                        return root.searching ? "Looking for devices" : "No devices found";
                    }
                    color: Theme.dim
                    font {
                        family: Theme.font
                        pixelSize: Theme.fontSize.normal
                    }
                }
            }
        }

        ListView {
            id: list

            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.on && root.devices.length > 0
            clip: true
            spacing: Theme.spacing.extraSmall
            boundsBehavior: Flickable.StopAtBounds
            model: root.devices

            delegate: Rectangle {
                id: row

                required property var modelData

                readonly property bool busy: row.modelData.pairing || row.modelData.state === Bluez.BluetoothDeviceState.Connecting || row.modelData.state === Bluez.BluetoothDeviceState.Disconnecting

                width: list.width
                implicitHeight: 46
                radius: Theme.rounding.large
                color: rowHover.hovered || row.modelData.connected ? Theme.bgTray : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Theme.duration.expressiveFastEffects
                    }
                }

                HoverHandler {
                    id: rowHover
                }

                RowLayout {
                    anchors {
                        fill: parent
                        leftMargin: Theme.padding.medium
                        rightMargin: Theme.padding.medium
                    }
                    spacing: Theme.spacing.medium

                    MaterialIcon {
                        text: root.glyph(row.modelData)
                        color: row.modelData.connected ? Theme.accentText : Theme.fg
                        size: Theme.icon.small
                    }

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.name || row.modelData.deviceName || "Unnamed device"
                        color: Theme.fg
                        elide: Text.ElideRight
                        font {
                            family: Theme.font
                            pixelSize: Theme.fontSize.smaller
                            weight: row.modelData.connected ? Theme.weight.medium : Theme.weight.regular
                        }
                    }

                    // Headphones report their own charge over BlueZ.
                    Text {
                        visible: row.modelData.connected && row.modelData.batteryAvailable
                        text: Math.round(row.modelData.battery * 100) + " %"
                        color: Theme.dim
                        font {
                            family: Theme.font
                            pixelSize: Theme.fontSize.small
                            features: ({
                                    tnum: 1
                                })
                        }
                    }

                    Spinner {
                        visible: row.busy
                    }

                    MaterialIcon {
                        visible: !row.busy && row.modelData.paired && rowHover.hovered
                        text: "link_off"
                        color: Theme.dim
                        size: Theme.icon.small

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -Theme.spacing.extraSmall
                            onClicked: row.modelData.forget()
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: !row.busy
                    // Pairing first, then connecting: BlueZ refuses a connection
                    // to a device it has never bonded with.
                    onClicked: {
                        if (row.modelData.connected)
                            row.modelData.disconnect();
                        else if (row.modelData.paired)
                            row.modelData.connect();
                        else
                            row.modelData.pair();
                    }
                }
            }
        }
    }
}
