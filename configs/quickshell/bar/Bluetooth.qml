pragma ComponentBehavior: Bound

import Quickshell
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

    Flyout {
        anchorItem: root
        visible: root.popupOpen
        title: "Bluetooth"
        busy: root.searching && root.devices.length > 0
        checked: root.on
        onToggled: root.adapter.enabled = !root.adapter.enabled
        onCloseRequested: root.popupOpen = false

        // Scanning drains the radio; run it only while the list is up. Held
        // only while this flyout is open, and handed back afterwards: every
        // screen has a bar, and one that always wrote would stop a scan another
        // screen, or another app, had started.
        Binding {
            target: root.adapter
            property: "discovering"
            value: root.on
            when: root.adapter !== null && root.popupOpen
        }

        // Every empty case says which one it is.
        FlyoutEmpty {
            visible: !root.adapter || !root.on || root.devices.length === 0
            searching: root.searching
            icon: root.on ? "bluetooth_searching" : "bluetooth_disabled"
            text: {
                if (!root.adapter)
                    return "No Bluetooth adapter";
                if (!root.on)
                    return "Bluetooth is off";
                return root.searching ? "Looking for devices" : "No devices found";
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
            // A ScriptModel, not the array: it diffs each new array against the last,
            // so an entry that is still there keeps its row instead of every row
            // being rebuilt whenever anything changes.
            model: ScriptModel {
                values: root.devices
            }

            delegate: FlyoutRow {
                id: row

                required property var modelData

                readonly property bool busy: row.modelData.pairing || row.modelData.state === Bluez.BluetoothDeviceState.Connecting || row.modelData.state === Bluez.BluetoothDeviceState.Disconnecting

                width: list.width
                active: row.modelData.connected


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
                        visible: !row.busy && row.modelData.paired && row.hovered
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
