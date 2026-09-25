pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth as Bluez
import ".."

// Imported as Bluez: this file's name shadows the module.
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

        // Only while this flyout is open, so other screens' scans survive.
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

            // Rows moving to the top (the connected one) otherwise scroll it out of view.
            property bool atTop: true
            onMovementEnded: atTop = atYBeginning
            onVisibleChanged: atTop = true
            Connections {
                target: root
                function onDevicesChanged(): void {
                    if (list.atTop)
                        Qt.callLater(list.positionViewAtBeginning);
                }
            }
            // ScriptModel diffs, so surviving rows are kept, not rebuilt.
            model: ScriptModel {
                values: root.devices
            }
            // Discovery takes seconds; until then only paired devices show.
            footer: FlyoutSearching {
                width: list.width
                searching: root.searching
                text: "Looking for devices"
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
                        color: Theme.fg
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

                    Text {
                        visible: row.modelData.connected && !row.busy
                        // Says what a click does.
                        text: row.hovered ? "Disconnect" : "Connected"
                        color: Theme.fg
                        font {
                            family: Theme.font
                            pixelSize: Theme.fontSize.small
                            weight: Theme.weight.medium
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
                    // BlueZ will not connect a device it has not bonded with.
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
