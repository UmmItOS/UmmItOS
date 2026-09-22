pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Bluetooth as Bluez
import QtQuick
import QtQuick.Layouts
import ".."

// Sits beside Wi-Fi and behaves the same way: a glyph in the bar, a flyout
// under it, and discovery running only while someone is looking.
//
// The module is imported under a namespace because this file is called
// Bluetooth too, and the local component would otherwise shadow the singleton.
RowLayout {
    id: root

    readonly property var adapter: Bluez.Bluetooth.defaultAdapter
    readonly property bool on: adapter?.enabled ?? false
    readonly property var connected: [...Bluez.Bluetooth.devices.values].find(d => d.connected) ?? null

    property bool popupOpen: false

    // Connected first, then the ones already paired, then by name. An address
    // is not a name, so anything nameless sorts last under its own label.
    readonly property var devices: [...Bluez.Bluetooth.devices.values].sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || (a.name ?? "").localeCompare(b.name ?? ""))

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
            if (!root.adapter)
                return "bluetooth_disabled";
            if (!root.on)
                return "bluetooth_disabled";
            return root.connected ? "bluetooth_connected" : "bluetooth";
        }
        color: root.connected ? Theme.fg : Theme.dim
    }

    TapHandler {
        onTapped: root.popupOpen = !root.popupOpen
    }

    HoverHandler {
        id: barHover
    }

    PopupWindow {
        id: popup

        anchor.item: root
        anchor.edges: Edges.Bottom
        anchor.gravity: Edges.Bottom
        anchor.margins.top: Theme.spacing.small

        visible: root.popupOpen
        implicitWidth: 380
        implicitHeight: 420
        color: "transparent"

        // Scanning drains the radio; run it only while the list is up.
        Binding {
            target: root.adapter
            property: "discovering"
            value: root.popupOpen && root.on
            when: root.adapter !== null
        }

        HoverHandler {
            id: popupHover
        }

        Timer {
            running: root.popupOpen && !popupHover.hovered && !barHover.hovered
            interval: 2500
            onTriggered: root.popupOpen = false
        }

        Surface {
            anchors.fill: parent
            radius: Theme.rounding.extraLarge
            tone: Theme.bg
            lift: 1.12

            ColumnLayout {
                anchors {
                    fill: parent
                    margins: Theme.padding.large
                }
                spacing: Theme.spacing.medium

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.spacing.medium

                    Text {
                        text: "Bluetooth"
                        color: Theme.fg
                        font.family: Theme.fontDisplay
                        font.pixelSize: Theme.fontSize.larger
                        font.weight: Theme.weight.bold
                    }

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 1

                        MaterialIcon {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            visible: (root.adapter?.discovering ?? false) && root.devices.length > 0
                            text: "progress_activity"
                            color: Theme.dim
                            size: Theme.icon.small

                            RotationAnimation on rotation {
                                running: parent.visible
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 900
                            }
                        }
                    }

                    // A switch, because the radio is a state rather than an action.
                    Rectangle {
                        implicitWidth: 46
                        implicitHeight: 26
                        radius: height / 2
                        color: root.on ? Theme.accent : Theme.bgTray
                        opacity: root.adapter ? 1 : 0.4

                        Behavior on color {
                            ColorAnimation {
                                duration: Theme.duration.expressiveFastEffects
                            }
                        }

                        Rectangle {
                            x: root.on ? parent.width - width - 3 : 3
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: 20
                            implicitHeight: 20
                            radius: width / 2
                            color: Theme.fg

                            Behavior on x {
                                NumberAnimation {
                                    duration: Theme.duration.expressiveFastSpatial
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: Theme.curve.expressiveDefaultSpatial
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: root.adapter !== null
                            onClicked: root.adapter.enabled = !root.adapter.enabled
                        }
                    }
                }

                // Every empty case says which one it is.
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: !root.adapter || !root.on || root.devices.length === 0

                    readonly property bool searching: root.on && (root.adapter?.discovering ?? false)

                    Column {
                        anchors.centerIn: parent
                        width: parent.width
                        spacing: Theme.spacing.medium

                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: !parent.parent.searching
                            text: root.on ? "bluetooth_searching" : "bluetooth_disabled"
                            color: Theme.dim
                            size: Theme.icon.large
                        }

                        MaterialIcon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: parent.parent.searching
                            text: "progress_activity"
                            color: Theme.dim
                            size: Theme.icon.large

                            RotationAnimation on rotation {
                                running: parent.visible
                                loops: Animation.Infinite
                                from: 0
                                to: 360
                                duration: 900
                            }
                        }

                        Text {
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            text: {
                                if (!root.adapter)
                                    return "No Bluetooth adapter";
                                if (!root.on)
                                    return "Bluetooth is off";
                                return parent.parent.searching ? "Looking for devices" : "No devices found";
                            }
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: Theme.fontSize.normal
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

                        readonly property bool busy: modelData.pairing || modelData.state === Bluez.BluetoothDeviceState.Connecting || modelData.state === Bluez.BluetoothDeviceState.Disconnecting

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
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize.smaller
                                font.weight: row.modelData.connected ? Theme.weight.medium : Theme.weight.regular
                                elide: Text.ElideRight
                            }

                            // Headphones report their own charge over BlueZ.
                            Text {
                                visible: row.modelData.connected && row.modelData.batteryAvailable
                                text: Math.round(row.modelData.battery * 100) + " %"
                                color: Theme.dim
                                font.family: Theme.font
                                font.pixelSize: Theme.fontSize.small
                                font.features: ({
                                        tnum: 1
                                    })
                            }

                            MaterialIcon {
                                visible: row.busy
                                text: "progress_activity"
                                color: Theme.dim
                                size: Theme.icon.small

                                RotationAnimation on rotation {
                                    running: row.busy
                                    loops: Animation.Infinite
                                    from: 0
                                    to: 360
                                    duration: 900
                                }
                            }

                            MaterialIcon {
                                visible: !row.busy && row.modelData.paired && rowHover.hovered
                                text: "link_off"
                                color: Theme.dim
                                size: Theme.icon.small

                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    onClicked: row.modelData.forget()
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: !row.busy
                            // Pairing first, then connecting: BlueZ refuses a
                            // connection to a device it has never bonded with.
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
    }
}
